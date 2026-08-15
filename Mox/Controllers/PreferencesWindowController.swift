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
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 700), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.minSize = NSSize(width: 520, height: 560)
        window.center()
        super.init(window: window)
        window.contentViewController = buildController()
        loadValues()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildController() -> NSViewController {
        let controller = NSViewController()
        let root = NSView()
        let scroll = NSScrollView()
        let document = NSView()

        let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseDirectory(_:)))
        choose.controlSize = .small
        directory.isEditable = false
        directory.isBezeled = false
        directory.drawsBackground = false
        directory.alignment = .right
        directory.textColor = .secondaryLabelColor
        directory.lineBreakMode = .byTruncatingMiddle
        directory.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let destination = NSStackView(views: [directory, choose])
        destination.spacing = 8

        [concurrent, split, connections, downloadLimit, uploadLimit, seedRatio, seedTime].forEach {
            $0.alignment = .right
            $0.controlSize = .regular
            $0.widthAnchor.constraint(equalToConstant: 92).isActive = true
        }

        let downloads = settingsSection("Downloads", rows: [
            settingRow("Default Location", control: destination),
            settingRow("Concurrent Downloads", control: concurrent),
            settingRow("Segments per Download", control: split),
            settingRow("Connections per Server", control: connections)
        ])

        let bandwidth = settingsSection("Bandwidth", rows: [
            settingRow("Download Speed Limit", control: downloadLimit),
            settingRow("Upload Speed Limit", control: uploadLimit)
        ])

        let speedHint = NSTextField(wrappingLabelWithString: "Use 0 for unlimited, or values such as 500K and 2M.")
        speedHint.textColor = .secondaryLabelColor
        speedHint.font = .preferredFont(forTextStyle: .caption1)

        let bitTorrent = settingsSection("BitTorrent", rows: [
            settingRow("Enable DHT", control: dht),
            settingRow("Enable IPv6 DHT", control: dht6),
            settingRow("Peer Exchange", control: pex),
            settingRow("Local Peer Discovery", control: lpd),
            settingRow("Require Encryption", control: encryption),
            settingRow("Seed Ratio", control: seedRatio),
            settingRow("Seed Time (minutes)", control: seedTime)
        ])

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        let save = NSButton(title: "Save and Restart Engine", target: self, action: #selector(save(_:)))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, save])
        buttons.alignment = .centerY
        buttons.spacing = 8

        let bandwidthGroup = NSStackView(views: [bandwidth, speedHint])
        bandwidthGroup.orientation = .vertical
        bandwidthGroup.alignment = .leading
        bandwidthGroup.spacing = 8

        let content = NSStackView(views: [downloads, bandwidthGroup, bitTorrent])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 20

        [downloads, bandwidthGroup, bitTorrent].forEach {
            $0.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        bandwidth.widthAnchor.constraint(equalTo: bandwidthGroup.widthAnchor).isActive = true
        speedHint.widthAnchor.constraint(equalTo: bandwidthGroup.widthAnchor, constant: -12).isActive = true

        document.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: document.topAnchor, constant: 22),
            content.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])

        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        document.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSVisualEffectView()
        footer.material = .headerView
        footer.blendingMode = .withinWindow
        footer.state = .active
        footer.addSubview(buttons)
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator

        [scroll, footer, separator].forEach(root.addSubview)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        footer.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),

            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: root.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: footer.topAnchor),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 64),

            buttons.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -20),
            buttons.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])

        controller.view = root
        return controller
    }

    private func settingsSection(_ title: String, rows: [NSView]) -> NSStackView {
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.textColor = .secondaryLabelColor
        let headingContainer = NSView()
        headingContainer.addSubview(heading)
        heading.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: headingContainer.leadingAnchor, constant: 12),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: headingContainer.trailingAnchor),
            heading.topAnchor.constraint(equalTo: headingContainer.topAnchor),
            heading.bottomAnchor.constraint(equalTo: headingContainer.bottomAnchor)
        ])

        let card = NSBox()
        card.boxType = .custom
        card.cornerRadius = 12
        card.borderWidth = 1
        card.borderColor = .separatorColor
        card.fillColor = .controlBackgroundColor

        let rowStack = NSStackView()
        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 0
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let separator = settingSeparator()
                rowStack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: rowStack.widthAnchor).isActive = true
            }
            rowStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowStack.widthAnchor).isActive = true
        }

        card.addSubview(rowStack)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: card.topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        let section = NSStackView(views: [headingContainer, card])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 7
        headingContainer.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        card.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private func settingRow(_ title: String, control: NSView) -> NSView {
        let row = NSView()
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        control.setAccessibilityLabel(title)

        row.addSubview(label)
        row.addSubview(control)
        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 48),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func settingSeparator() -> NSView {
        let container = NSView()
        let separator = NSBox()
        separator.boxType = .separator
        container.addSubview(separator)
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 1),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 1),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
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
