import Foundation

nonisolated enum TaskCategory: Int, CaseIterable {
    case downloading
    case waiting
    case completed
    case failed

    var title: String {
        switch self {
        case .downloading: "Downloading"
        case .waiting: "Waiting"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }
}

nonisolated struct Aria2Task: Codable, Identifiable, Hashable {
    let gid: String
    let status: String
    let totalLength: String
    let completedLength: String
    let uploadLength: String?
    let downloadSpeed: String
    let uploadSpeed: String?
    let connections: String?
    let dir: String
    let files: [Aria2File]
    let bittorrent: BitTorrentInfo?
    let infoHash: String?
    let numSeeders: String?
    let seeder: String?
    let errorCode: String?
    let errorMessage: String?
    let followedBy: [String]?
    let following: String?

    var id: String { gid }
    var totalBytes: Int64 { Int64(totalLength) ?? 0 }
    var completedBytes: Int64 { Int64(completedLength) ?? 0 }
    var bytesPerSecond: Int64 { Int64(downloadSpeed) ?? 0 }
    var progress: Double { totalBytes > 0 ? min(1, Double(completedBytes) / Double(totalBytes)) : 0 }
    var eta: TimeInterval? {
        let remaining = totalBytes - completedBytes
        return remaining > 0 && bytesPerSecond > 0 ? TimeInterval(remaining / bytesPerSecond) : nil
    }
    var displayName: String {
        if let name = bittorrent?.info?.name, !name.isEmpty { return name }
        if let path = files.first?.path, !path.isEmpty { return URL(fileURLWithPath: path).lastPathComponent }
        return gid
    }
    var category: TaskCategory {
        switch status {
        case "active": .downloading
        case "waiting", "paused": .waiting
        case "complete", "removed": .completed
        default: .failed
        }
    }
    var canPause: Bool { status == "active" || status == "waiting" }
    var canResume: Bool { status == "paused" || status == "error" }
}

nonisolated struct Aria2File: Codable, Hashable {
    let index: String
    let path: String
    let length: String
    let completedLength: String
    let selected: String?
    let uris: [Aria2FileURI]
}

nonisolated struct Aria2FileURI: Codable, Hashable {
    let uri: String
    let status: String
}

nonisolated struct BitTorrentInfo: Codable, Hashable {
    let announceList: [[String]]?
    let comment: String?
    let creationDate: Int?
    let mode: String?
    let info: BitTorrentInfoName?
}

nonisolated struct BitTorrentInfoName: Codable, Hashable { let name: String? }

nonisolated struct Aria2Peer: Codable, Hashable {
    let peerId: String?
    let ip: String
    let port: String
    let bitfield: String?
    let amChoking: String?
    let peerChoking: String?
    let downloadSpeed: String
    let uploadSpeed: String
    let seeder: String?
}

nonisolated struct Aria2GlobalStat: Codable {
    let downloadSpeed: String
    let uploadSpeed: String
    let numActive: String
    let numWaiting: String
    let numStopped: String
}

nonisolated struct Aria2Version: Codable {
    let version: String
    let enabledFeatures: [String]
}

nonisolated struct RPCResponse<Result: Decodable>: Decodable {
    let result: Result?
    let error: RPCError?
}

nonisolated struct RPCError: Codable, Error, LocalizedError {
    let code: Int
    let message: String
    var errorDescription: String? { message }
}

enum DisplayFormat {
    static let bytes = ByteCountFormatter()

    static func size(_ value: Int64) -> String {
        bytes.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        bytes.countStyle = .file
        return bytes.string(fromByteCount: value)
    }

    static func speed(_ value: Int64) -> String { "\(size(value))/s" }

    static func duration(_ value: TimeInterval?) -> String {
        guard let value, value.isFinite else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = value >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: value) ?? "—"
    }
}
