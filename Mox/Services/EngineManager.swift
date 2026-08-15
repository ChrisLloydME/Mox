import Foundation
import Darwin

enum EngineState: Equatable {
    case stopped
    case starting
    case ready
    case failed(String)
}

@MainActor
final class EngineManager {
    private(set) var state: EngineState = .stopped { didSet { onStateChange?(state) } }
    var onStateChange: ((EngineState) -> Void)?
    private(set) var client: Aria2Client?
    private var process: Process?
    private var monitorTask: Task<Void, Never>?
    private let fileManager: FileManager
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore, fileManager: FileManager = .default) {
        self.settingsStore = settingsStore
        self.fileManager = fileManager
    }

    func start() async {
        guard process == nil else { return }
        state = .starting
        do {
            let settings = settingsStore.value
            try fileManager.createDirectory(atPath: settings.downloadDirectory, withIntermediateDirectories: true)
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Mox", isDirectory: true)
            try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
            let sessionFile = support.appendingPathComponent("downloads.session")
            let logFile = support.appendingPathComponent("aria2.log")
            guard let executable = Bundle.main.url(forResource: "aria2-next", withExtension: nil) else {
                throw RPCError(code: -10, message: "The bundled Aria2 Next engine is missing.")
            }
            let child = Process()
            child.executableURL = executable
            var arguments: [String] = []
            if let configuration = Bundle.main.url(forResource: "aria2", withExtension: "conf") {
                arguments.append("--conf-path=\(configuration.path)")
            }
            arguments += [
                "--enable-rpc=true", "--rpc-listen-all=false", "--rpc-listen-port=29100",
                "--rpc-secret=\(settings.rpcSecret)", "--rpc-allow-origin-all=false",
                "--save-session=\(sessionFile.path)", "--save-session-interval=10",
                "--auto-save-interval=10", "--continue=true",
                "--log=\(logFile.path)", "--log-level=notice", "--quiet=true"
            ]
            if fileManager.fileExists(atPath: sessionFile.path) { arguments.append("--input-file=\(sessionFile.path)") }
            arguments += settings.engineOptions.map { "--\($0.key)=\($0.value)" }
            child.arguments = arguments
            child.standardOutput = FileHandle.nullDevice
            child.standardError = FileHandle.nullDevice
            try child.run()
            process = child
            let rpc = Aria2Client(secret: settings.rpcSecret)
            try await rpc.waitUntilReady()
            client = rpc
            state = .ready
            monitorTask = Task { [weak self, weak child] in
                while let child, child.isRunning, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(250)) }
                guard let self, !Task.isCancelled, self.process === child, self.state == .ready else { return }
                self.process = nil
                self.client = nil
                self.state = .failed("The download engine exited unexpectedly.")
            }
        } catch {
            process?.terminate()
            process = nil
            client = nil
            state = .failed(error.localizedDescription)
        }
    }

    func restart() async {
        await stop()
        await start()
    }

    func stop() async {
        state = .stopped
        monitorTask?.cancel()
        monitorTask = nil
        if let client {
            try? await client.saveSession()
            try? await client.shutdown()
        }
        if let process, process.isRunning {
            for _ in 0..<20 where process.isRunning { try? await Task.sleep(for: .milliseconds(100)) }
            if process.isRunning { kill(process.processIdentifier, SIGTERM) }
            for _ in 0..<20 where process.isRunning { try? await Task.sleep(for: .milliseconds(100)) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        process = nil
        client = nil
    }
}
