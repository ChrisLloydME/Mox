import AppKit
import Foundation
import Testing
@testable import Mox

struct MoxTests {
    @Test @MainActor func addDownloadThreadSliderClampsToSupportedRange() {
        let model = AddDownloadOptionsModel(directory: "/Downloads", threads: 5)

        model.setThreadCount(32)
        #expect(model.threads == 32)

        model.setThreadCount(0)
        #expect(model.threads == 1)

        model.setThreadCount(65)
        #expect(model.threads == 64)
    }

    @Test func perDownloadThreadsSetSplitAndServerConnectionLimit() {
        let options = Aria2Client.downloadOptions(directory: "/Downloads", threads: 16)

        #expect(options["dir"] == "/Downloads")
        #expect(options["split"] == "16")
        #expect(options["max-connection-per-server"] == "16")
    }

    @Test @MainActor func toolbarActionsUsePauseResumeDetailsRemoveOrder() {
        let controller = ViewController()
        let toolbar = NSToolbar(identifier: "ToolbarOrderTest")
        let identifiers = controller.toolbarDefaultItemIdentifiers(toolbar)
        #expect(identifiers.suffix(4).map(\.rawValue) == ["pause", "resume", "details", "remove"])
    }

    @Test @MainActor func aboutMenuOpensAboutWindow() throws {
        let aboutItem = try #require(NSApp.mainMenu?.items.first?.submenu?.item(withTitle: "About Mox"))
        let action = try #require(aboutItem.action)
        #expect(NSApp.sendAction(action, to: aboutItem.target, from: aboutItem))
        let aboutWindow = try #require(NSApp.windows.first { $0.title == "About Mox" })
        #expect(aboutWindow.isVisible)
        #expect(aboutWindow.contentLayoutRect.size == NSSize(width: 660, height: 354))
        #expect(aboutWindow.contentView?.findView(withIdentifier: "about.applicationName") != nil)
        #expect(aboutWindow.contentView?.findView(withIdentifier: "about.applicationIcon") != nil)
        let copyright = try #require(
            aboutWindow.contentView?.findView(withIdentifier: "about.copyright") as? NSTextField
        )
        #expect(copyright.stringValue.contains("Christopher Lloyd. \nMox includes"))
        aboutWindow.close()
        #expect(!aboutWindow.isVisible)
        #expect(NSApp.sendAction(action, to: aboutItem.target, from: aboutItem))
        #expect(aboutWindow.isVisible)
        aboutWindow.close()
    }

    @Test @MainActor func dockReopenRestoresMainWindow() throws {
        let delegate = try #require(NSApp.delegate as? AppDelegate)
        let mainWindow = try #require(NSApp.windows.first { $0.contentViewController is ViewController })
        mainWindow.orderOut(nil)
        #expect(!mainWindow.isVisible)
        #expect(delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false))
        #expect(mainWindow.isVisible)
    }

    @Test @MainActor func settingsCloseDoesNotPreventMainWindowReopen() throws {
        let delegate = try #require(NSApp.delegate as? AppDelegate)
        let mainWindow = try #require(NSApp.windows.first { $0.contentViewController is ViewController })
        delegate.showPreferences(nil)
        let settingsWindow = try #require(NSApp.windows.first { $0.title == "Settings" })
        #expect(settingsWindow.isVisible)
        settingsWindow.performClose(nil)
        #expect(!settingsWindow.isVisible)
        delegate.showPreferences(nil)
        #expect(settingsWindow.isVisible)
        settingsWindow.performClose(nil)
        #expect(!settingsWindow.isVisible)

        mainWindow.performClose(nil)
        #expect(!mainWindow.isVisible)
        #expect(delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: true))
        #expect(mainWindow.isVisible)
    }

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

    @Test func taskDecodesPieceBitfieldMostSignificantBitFirst() throws {
        let json = #"""
        {
          "gid":"pieces", "status":"active", "totalLength":"80", "completedLength":"40",
          "downloadSpeed":"1", "dir":"/tmp", "files":[], "bitfield":"a8", "numPieces":"6"
        }
        """#.data(using: .utf8)!
        let task = try JSONDecoder().decode(Aria2Task.self, from: json)
        #expect(task.pieceStates == [true, false, true, false, true, false])
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

private extension NSView {
    func findView(withIdentifier identifier: String) -> NSView? {
        if self.identifier?.rawValue == identifier { return self }
        return subviews.lazy.compactMap { $0.findView(withIdentifier: identifier) }.first
    }
}
