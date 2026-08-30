import AppKit
import Foundation

@MainActor
final class TaskStore {
    private(set) var tasks: [Aria2Task] = [] { didSet { onChange?() } }
    private(set) var lastError: String? { didSet { onChange?() } }
    var onChange: (() -> Void)?
    var clientProvider: () -> Aria2Client?
    private var pollTask: Task<Void, Never>?
    private let historyURL: URL

    init(clientProvider: @escaping () -> Aria2Client?, fileManager: FileManager = .default) {
        self.clientProvider = clientProvider
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Mox", isDirectory: true)
        historyURL = base.appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: historyURL), let history = try? JSONDecoder().decode([Aria2Task].self, from: data) {
            tasks = history
        }
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() { pollTask?.cancel(); pollTask = nil }

    func refresh() async {
        guard let client = clientProvider() else { return }
        do {
            let current = try await client.tasks()
            let currentIDs = Set(current.map(\.gid))
            let historyOnly = tasks.filter { !currentIDs.contains($0.gid) && [.completed, .failed].contains($0.category) }
            tasks = (current + historyOnly).sorted { lhs, rhs in
                if lhs.category.rawValue != rhs.category.rawValue { return lhs.category.rawValue < rhs.category.rawValue }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            lastError = nil
            persistHistory()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func add(text: String, directory: String, split: Int) async throws {
        let values = text.components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: CharacterSet.whitespaces) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !values.isEmpty else { throw RPCError(code: -20, message: "Enter an HTTP, HTTPS, or Magnet link.") }
        guard values.allSatisfy({ value in
            guard let scheme = URLComponents(string: value)?.scheme?.lowercased() else { return false }
            return ["http", "https", "magnet"].contains(scheme)
        }) else { throw RPCError(code: -21, message: "Only HTTP, HTTPS, and Magnet links are supported in this version.") }
        guard (1...64).contains(split) else { throw RPCError(code: -24, message: "Thread count must be between 1 and 64.") }
        guard let client = clientProvider() else { throw RPCError(code: -22, message: "The download engine is not ready.") }
        for value in values { _ = try await client.add(uris: [value], directory: directory, split: split) }
        await refresh()
    }

    func addTorrent(url: URL, directory: String) async throws {
        guard url.pathExtension.lowercased() == "torrent" else { throw RPCError(code: -23, message: "Choose a .torrent file.") }
        guard let client = clientProvider() else { throw RPCError(code: -22, message: "The download engine is not ready.") }
        _ = try await client.addTorrent(data: try Data(contentsOf: url), directory: directory)
        await refresh()
    }

    func pause(_ task: Aria2Task) async throws {
        try await pause([task])
    }

    func pause(_ tasks: [Aria2Task]) async throws {
        guard let client = clientProvider() else { throw RPCError(code: -22, message: "The download engine is not ready.") }
        var firstError: Error?
        for task in tasks where task.canPause {
            do { try await client.pause(gid: task.gid) }
            catch { firstError = firstError ?? error }
        }
        await refresh()
        if let firstError { throw firstError }
    }

    func resume(_ task: Aria2Task) async throws {
        try await resume([task])
    }

    func resume(_ tasks: [Aria2Task]) async throws {
        guard let client = clientProvider() else { throw RPCError(code: -22, message: "The download engine is not ready.") }
        var firstError: Error?
        for task in tasks where task.canResume {
            do { try await client.resume(gid: task.gid) }
            catch { firstError = firstError ?? error }
        }
        await refresh()
        if let firstError { throw firstError }
    }

    func remove(_ task: Aria2Task, deleteFiles: Bool) async throws {
        try await remove([task], deleteFiles: deleteFiles)
    }

    func remove(_ selectedTasks: [Aria2Task], deleteFiles: Bool) async throws {
        let client = clientProvider()
        var removedIDs: Set<String> = []
        var firstError: Error?

        for task in selectedTasks {
            do {
                if ["active", "waiting", "paused"].contains(task.status) {
                    guard let client else { throw RPCError(code: -22, message: "The download engine is not ready.") }
                    try await client.remove(gid: task.gid)
                }
                if let client { try? await client.removeResult(gid: task.gid) }
                removedIDs.insert(task.gid)
                if deleteFiles {
                    for path in deletionTargets(for: task, files: task.files) {
                        try FileManager.default.trashItem(at: path, resultingItemURL: nil)
                    }
                }
            } catch {
                firstError = firstError ?? error
            }
        }

        tasks.removeAll { removedIDs.contains($0.gid) }
        persistHistory()
        await refresh()
        if let firstError { throw firstError }
    }

    private func deletionTargets(for task: Aria2Task, files: [Aria2File]) -> [URL] {
        let existing = files.map { URL(fileURLWithPath: $0.path) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard existing.count > 1 else { return existing }
        let base = URL(fileURLWithPath: task.dir).standardizedFileURL
        let firstComponents = existing[0].standardizedFileURL.pathComponents
        let baseCount = base.pathComponents.count
        guard firstComponents.count > baseCount else { return existing }
        let top = base.appendingPathComponent(firstComponents[baseCount])
        if existing.allSatisfy({ $0.standardizedFileURL.path.hasPrefix(top.path + "/") }) { return [top] }
        return existing
    }

    private func persistHistory() {
        let history = tasks.filter { [.completed, .failed].contains($0.category) }
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: historyURL, options: .atomic)
    }
}
