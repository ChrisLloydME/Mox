import Foundation
import Testing
@testable import Mox

struct MoxTests {
    @Test func taskDecodesAriaResponseAndCalculatesProgress() throws {
        let json = #"""
        {
          "gid":"abc123", "status":"active", "totalLength":"1000", "completedLength":"250",
          "uploadLength":"0", "downloadSpeed":"50", "uploadSpeed":"0", "connections":"2",
          "dir":"/Downloads", "files":[{"index":"1","path":"/Downloads/example.zip","length":"1000","completedLength":"250","selected":"true","uris":[]}]
        }
        """#.data(using: .utf8)!
        let task = try JSONDecoder().decode(Aria2Task.self, from: json)
        #expect(task.displayName == "example.zip")
        #expect(task.category == .downloading)
        #expect(task.progress == 0.25)
        #expect(task.eta == 15)
    }

    @Test func taskCategoriesMatchAriaStates() throws {
        func task(status: String) throws -> Aria2Task {
            let json = """
            {"gid":"1","status":"\(status)","totalLength":"0","completedLength":"0","downloadSpeed":"0","dir":"/tmp","files":[]}
            """.data(using: .utf8)!
            return try JSONDecoder().decode(Aria2Task.self, from: json)
        }
        #expect(try task(status: "paused").category == .waiting)
        #expect(try task(status: "complete").category == .completed)
        #expect(try task(status: "error").category == .failed)
    }

    @Test func settingsProduceExpectedEngineOptions() {
        var settings = AppSettings.defaults()
        settings.downloadDirectory = "/Downloads"
        settings.maxConcurrentDownloads = 8
        settings.split = 12
        settings.enableDHT6 = false
        let options = settings.engineOptions
        #expect(options["dir"] == "/Downloads")
        #expect(options["max-concurrent-downloads"] == "8")
        #expect(options["split"] == "12")
        #expect(options["enable-dht6"] == "false")
        #expect(settings.rpcPort == 29_100)
        #expect(!settings.rpcSecret.isEmpty)
    }
}
