import Cocoa

final class PreferencesWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let onSave: (AppSettings) throws -> Void
    private let directory = NSTextField()
    private let concurrent = NSTextField()
    private let split = NSTextField()
    private let connections = NSTextField()
    private let downloadLimit = NSTextField()
    private let uploadLimit = NSTextField()
    private let dht = NSButton(checkboxWithTitle: "Enable DHT", target: nil, action: nil)
    private let dht6 = NSButton(checkboxWithTitle: "Enable IPv6 DHT", target: nil, action: nil)
    private let pex = NSButton(checkboxWithTitle: "Enable peer exchange", target: nil, action: nil)
    private let lpd = NSButton(checkboxWithTitle: "Enable local peer discovery", target: nil, action: nil)
    private let encryption = NSButton(checkboxWithTitle: "Require BitTorrent encryption", target: nil, action: nil)
    private let seedRatio = NSTextField()
    private let seedTime = NSTextField()

    init(settingsStore: SettingsStore, onSave: @escaping (AppSettings) throws -> Void) {
        self.settingsStore = settingsStore
        self.onSave = onSave
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 600), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Mox Settings"
        window.center()
        super.init(window: window)
        window.contentViewController = buildController()
        loadValues()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildController() -> NSViewController {
        let controller = NSViewController()
        let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseDirectory(_:)))
        directory.isEditable = false
        directory.lineBreakMode = .byTruncatingMiddle
        directory.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let destination = NSStackView(views: [directory, choose])
        destination.spacing = 8

        let downloadsGrid = NSGridView(views: [
            [label("Default location:"), destination],
            [label("Concurrent downloads:"), concurrent],
            [label("Segments per download:"), split],
            [label("Connections per server:"), connections],
            [label("Download speed limit:"), downloadLimit],
            [label("Upload speed limit:"), uploadLimit]
        ])
        downloadsGrid.column(at: 0).xPlacement = .trailing
        downloadsGrid.column(at: 1).xPlacement = .leading
        downloadsGrid.rowSpacing = 8
        downloadsGrid.columnSpacing = 10
        [concurrent, split, connections].forEach { $0.widthAnchor.constraint(equalToConstant: 72).isActive = true }
        [downloadLimit, uploadLimit].forEach { $0.widthAnchor.constraint(equalToConstant: 120).isActive = true }

        let speedHint = NSTextField(wrappingLabelWithString: "Use 0 for unlimited, or values such as 500K and 2M.")
        speedHint.textColor = .secondaryLabelColor
        speedHint.font = .preferredFont(forTextStyle: .caption1)

        let btGrid = NSGridView(views: [
            [label("Seed ratio:"), seedRatio],
            [label("Seed time (minutes):"), seedTime]
        ])
        btGrid.column(at: 0).xPlacement = .trailing
        btGrid.column(at: 1).xPlacement = .leading
        btGrid.rowSpacing = 8
        btGrid.columnSpacing = 10
        [seedRatio, seedTime].forEach { $0.widthAnchor.constraint(equalToConstant: 100).isActive = true }

        let checks = NSStackView(views: [dht, dht6, pex, lpd, encryption])
        checks.orientation = .vertical
        checks.alignment = .leading
        checks.spacing = 6

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        let save = NSButton(title: "Save and Restart Engine", target: self, action: #selector(save(_:)))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, save])
        buttons.alignment = .centerY
        buttons.spacing = 8

        let content = NSStackView(views: [section("Downloads"), downloadsGrid, speedHint, section("BitTorrent"), btGrid, checks, buttons])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 12
        content.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 20, right: 24)
        buttons.alignment = .centerY
        buttons.setContentHuggingPriority(.required, for: .horizontal)
        controller.view = content
        return controller
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }

    private func section(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .preferredFont(forTextStyle: .headline)
        return field
    }

    private func loadValues() {
        let value = settingsStore.value
        directory.stringValue = value.downloadDirectory
        concurrent.integerValue = value.maxConcurrentDownloads
        split.integerValue = value.split
        connections.integerValue = value.maxConnectionsPerServer
        downloadLimit.stringValue = value.maxOverallDownloadLimit
        uploadLimit.stringValue = value.maxOverallUploadLimit
        dht.state = value.enableDHT ? .on : .off
        dht6.state = value.enableDHT6 ? .on : .off
        pex.state = value.enablePeerExchange ? .on : .off
        lpd.state = value.enableLocalPeerDiscovery ? .on : .off
        encryption.state = value.requireEncryption ? .on : .off
        seedRatio.doubleValue = value.seedRatio
        seedTime.integerValue = value.seedTimeMinutes
    }

    @objc private func chooseDirectory(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: directory.stringValue)
        panel.begin { [weak self] response in
            if response == .OK, let path = panel.url?.path { self?.directory.stringValue = path }
        }
    }

    @objc private func cancel(_ sender: Any?) { close() }

    @objc private func save(_ sender: Any?) {
        guard (1...100).contains(concurrent.integerValue),
              (1...64).contains(split.integerValue),
              (1...64).contains(connections.integerValue),
              seedRatio.doubleValue >= 0,
              seedTime.integerValue >= 0,
              isValidSpeed(downloadLimit.stringValue),
              isValidSpeed(uploadLimit.stringValue),
              directory.stringValue.hasPrefix("/") else {
            return showError("Check the destination and numeric values. Concurrency must be 1–100, connection values 1–64, and speed limits values such as 0, 500K, or 2M.")
        }
        var value = settingsStore.value
        value.downloadDirectory = directory.stringValue
        value.maxConcurrentDownloads = concurrent.integerValue
        value.split = split.integerValue
        value.maxConnectionsPerServer = connections.integerValue
        value.maxOverallDownloadLimit = downloadLimit.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        value.maxOverallUploadLimit = uploadLimit.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        value.enableDHT = dht.state == .on
        value.enableDHT6 = dht6.state == .on
        value.enablePeerExchange = pex.state == .on
        value.enableLocalPeerDiscovery = lpd.state == .on
        value.requireEncryption = encryption.state == .on
        value.seedRatio = seedRatio.doubleValue
        value.seedTimeMinutes = seedTime.integerValue
        do {
            try onSave(value)
            close()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Settings could not be saved"
        alert.informativeText = message
        alert.alertStyle = .warning
        if let window { alert.beginSheetModal(for: window) }
    }

    private func isValidSpeed(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).range(of: #"^(0|[1-9][0-9]*[KMGkmg]?)$"#, options: .regularExpression) != nil
    }
}
