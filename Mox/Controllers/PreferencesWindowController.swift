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
    private let dht = NSSwitch()
    private let dht6 = NSSwitch()
    private let pex = NSSwitch()
    private let lpd = NSSwitch()
    private let encryption = NSSwitch()
    private let seedRatio = NSTextField()
    private let seedTime = NSTextField()

    init(settingsStore: SettingsStore, onSave: @escaping (AppSettings) throws -> Void) {
        self.settingsStore = settingsStore
        self.onSave = onSave
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 640), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.center()
        super.init(window: window)
        window.contentViewController = buildController()
        loadValues()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildController() -> NSViewController {
        let controller = NSViewController()
        let root = NSView()

        let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseDirectory(_:)))
        directory.isEditable = false
        directory.lineBreakMode = .byTruncatingMiddle
        directory.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let destination = NSStackView(views: [directory, choose])
        destination.spacing = 8

        [concurrent, split, connections, downloadLimit, uploadLimit, seedRatio, seedTime].forEach {
            $0.alignment = .right
        }
        [concurrent, split, connections, seedRatio, seedTime].forEach {
            $0.widthAnchor.constraint(equalToConstant: 88).isActive = true
        }
        [downloadLimit, uploadLimit].forEach {
            $0.widthAnchor.constraint(equalToConstant: 120).isActive = true
        }

        let downloads = formSection("Downloads", rows: [
            ("Default location:", destination),
            ("Concurrent downloads:", concurrent),
            ("Segments per download:", split),
            ("Connections per server:", connections)
        ])

        let bandwidth = formSection("Bandwidth", rows: [
            ("Download speed limit:", downloadLimit),
            ("Upload speed limit:", uploadLimit)
        ])

        let speedHint = NSTextField(wrappingLabelWithString: "Use 0 for unlimited, or values such as 500K and 2M.")
        speedHint.textColor = .secondaryLabelColor
        speedHint.font = .preferredFont(forTextStyle: .caption1)

        let bitTorrent = formSection("BitTorrent", rows: [
            ("DHT:", dht),
            ("IPv6 DHT:", dht6),
            ("Peer exchange:", pex),
            ("Local peer discovery:", lpd),
            ("Require encryption:", encryption),
            ("Seed ratio:", seedRatio),
            ("Seed time (minutes):", seedTime)
        ])

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        let save = NSButton(title: "Save and Restart Engine", target: self, action: #selector(save(_:)))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, save])
        buttons.alignment = .centerY
        buttons.spacing = 8

        let content = NSStackView(views: [downloads, bandwidth, speedHint, bitTorrent])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 16

        root.addSubview(content)
        root.addSubview(buttons)
        content.translatesAutoresizingMaskIntoConstraints = false
        buttons.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            content.bottomAnchor.constraint(lessThanOrEqualTo: buttons.topAnchor, constant: -18),
            buttons.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])

        controller.view = root
        return controller
    }

    private func formSection(_ title: String, rows: [(String, NSView)]) -> NSStackView {
        let heading = NSTextField(labelWithString: title)
        heading.font = .preferredFont(forTextStyle: .headline)

        let grid = NSGridView(views: rows.map { row in
            let (title, control) = row
            control.setAccessibilityLabel(title.replacingOccurrences(of: ":", with: ""))
            let label = NSTextField(labelWithString: title)
            label.alignment = .right
            return [label, control]
        })
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        grid.rowSpacing = 9
        grid.columnSpacing = 10

        let section = NSStackView(views: [heading, grid])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 10
        return section
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
