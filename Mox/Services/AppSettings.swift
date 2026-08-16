import Foundation

struct AppSettings: Codable, Equatable {
    var downloadDirectory: String
    var maxConcurrentDownloads = 6
    var split = 5
    var maxConnectionsPerServer = 5
    var maxOverallDownloadLimit = "0"
    var maxOverallUploadLimit = "0"
    var enableDHT = true
    var enableDHT6 = true
    var enablePeerExchange = true
    var enableLocalPeerDiscovery = true
    var requireEncryption = false
    var seedRatio = 2.0
    var seedTimeMinutes = 2_880
    var rpcSecret: String
    var rpcPort: Int?

    static func defaults(fileManager: FileManager = .default) -> AppSettings {
        let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory() + "/Downloads"
        return AppSettings(downloadDirectory: downloads, rpcSecret: UUID().uuidString.replacingOccurrences(of: "-", with: ""), rpcPort: 29_100)
    }

    var engineOptions: [String: String] {
        [
            "dir": downloadDirectory,
            "max-concurrent-downloads": String(maxConcurrentDownloads),
            "split": String(split),
            "max-connection-per-server": String(maxConnectionsPerServer),
            "max-overall-download-limit": maxOverallDownloadLimit,
            "max-overall-upload-limit": maxOverallUploadLimit,
            "enable-dht": String(enableDHT),
            "enable-dht6": String(enableDHT6),
            "enable-peer-exchange": String(enablePeerExchange),
            "bt-enable-lpd": String(enableLocalPeerDiscovery),
            "bt-force-encryption": String(requireEncryption),
            "seed-ratio": String(seedRatio),
            "seed-time": String(seedTimeMinutes)
        ]
    }
}

final class SettingsStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private(set) var value: AppSettings

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Mox", isDirectory: true)
        fileURL = base.appendingPathComponent("settings.json")
        if let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            value = decoded
        } else {
            value = .defaults(fileManager: fileManager)
            try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONEncoder.pretty.encode(value) { try? data.write(to: fileURL, options: .atomic) }
        }
    }

    func save(_ settings: AppSettings) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(settings)
        try data.write(to: fileURL, options: .atomic)
        value = settings
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
