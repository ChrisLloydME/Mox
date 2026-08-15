import Cocoa
import Combine
import SwiftUI

final class PreferencesWindowController: NSWindowController, NSToolbarDelegate {
    private let settingsStore: SettingsStore
    private let onSave: (AppSettings) throws -> Void
    private let model: PreferencesModel

    init(settingsStore: SettingsStore, onSave: @escaping (AppSettings) throws -> Void) {
        self.settingsStore = settingsStore
        self.onSave = onSave
        model = PreferencesModel(settings: settingsStore.value)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 520, height: 560)
        window.toolbarStyle = .unified
        window.center()
        super.init(window: window)

        let toolbar = NSToolbar(identifier: .preferences)
        toolbar.delegate = self
        toolbar.sizeMode = .regular
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.contentViewController = NSHostingController(rootView: PreferencesView(
            model: model,
            chooseDirectory: { [weak self] in self?.chooseDirectory() }
        ))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        model.load(settings: settingsStore.value)
        super.showWindow(sender)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .cancel, .save]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        let button: NSButton
        switch identifier {
        case .cancel:
            item.label = "Cancel"
            button = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
            button.keyEquivalent = "\u{1b}"
        case .save:
            item.label = "Save"
            button = NSButton(title: "Save", target: self, action: #selector(saveFromToolbar(_:)))
            button.keyEquivalent = "\r"
        default:
            return nil
        }
        button.controlSize = .large
        if #available(macOS 26.0, *) {
            button.bezelStyle = .glass
        } else {
            button.bezelStyle = .toolbar
        }
        item.paletteLabel = item.label
        item.view = button
        return item
    }

    @objc private func cancel(_ sender: Any?) { close() }

    @objc private func saveFromToolbar(_ sender: Any?) { save() }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: model.downloadDirectory)
        panel.begin { [weak self] response in
            if response == .OK, let path = panel.url?.path {
                self?.model.downloadDirectory = path
            }
        }
    }

    private func save() {
        guard let concurrent = Int(model.concurrentDownloads), (1...100).contains(concurrent),
              let split = Int(model.segmentsPerDownload), (1...64).contains(split),
              let connections = Int(model.connectionsPerServer), (1...64).contains(connections),
              let seedRatio = Double(model.seedRatio), seedRatio >= 0,
              let seedTime = Int(model.seedTimeMinutes), seedTime >= 0,
              isValidSpeed(model.downloadSpeedLimit),
              isValidSpeed(model.uploadSpeedLimit),
              model.downloadDirectory.hasPrefix("/") else {
            return showError("Check the destination and numeric values. Concurrency must be 1–100, connection values 1–64, and speed limits values such as 0, 500K, or 2M.")
        }

        var value = settingsStore.value
        value.downloadDirectory = model.downloadDirectory
        value.maxConcurrentDownloads = concurrent
        value.split = split
        value.maxConnectionsPerServer = connections
        value.maxOverallDownloadLimit = model.downloadSpeedLimit.trimmingCharacters(in: .whitespacesAndNewlines)
        value.maxOverallUploadLimit = model.uploadSpeedLimit.trimmingCharacters(in: .whitespacesAndNewlines)
        value.enableDHT = model.enableDHT
        value.enableDHT6 = model.enableDHT6
        value.enablePeerExchange = model.enablePeerExchange
        value.enableLocalPeerDiscovery = model.enableLocalPeerDiscovery
        value.requireEncryption = model.requireEncryption
        value.seedRatio = seedRatio
        value.seedTimeMinutes = seedTime

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
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: #"^(0|[1-9][0-9]*[KMGkmg]?)$"#, options: .regularExpression) != nil
    }
}

private final class PreferencesModel: ObservableObject {
    @Published var downloadDirectory = ""
    @Published var concurrentDownloads = ""
    @Published var segmentsPerDownload = ""
    @Published var connectionsPerServer = ""
    @Published var downloadSpeedLimit = ""
    @Published var uploadSpeedLimit = ""
    @Published var enableDHT = false
    @Published var enableDHT6 = false
    @Published var enablePeerExchange = false
    @Published var enableLocalPeerDiscovery = false
    @Published var requireEncryption = false
    @Published var seedRatio = ""
    @Published var seedTimeMinutes = ""

    init(settings: AppSettings) {
        load(settings: settings)
    }

    func load(settings: AppSettings) {
        downloadDirectory = settings.downloadDirectory
        concurrentDownloads = String(settings.maxConcurrentDownloads)
        segmentsPerDownload = String(settings.split)
        connectionsPerServer = String(settings.maxConnectionsPerServer)
        downloadSpeedLimit = settings.maxOverallDownloadLimit
        uploadSpeedLimit = settings.maxOverallUploadLimit
        enableDHT = settings.enableDHT
        enableDHT6 = settings.enableDHT6
        enablePeerExchange = settings.enablePeerExchange
        enableLocalPeerDiscovery = settings.enableLocalPeerDiscovery
        requireEncryption = settings.requireEncryption
        seedRatio = String(settings.seedRatio)
        seedTimeMinutes = String(settings.seedTimeMinutes)
    }
}

private struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel
    let chooseDirectory: () -> Void

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            settingsForm
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectHidden(true, for: .bottom)
                .frame(minWidth: 520, minHeight: 560)
        } else {
            settingsForm
                .frame(minWidth: 520, minHeight: 560)
        }
    }

    private var settingsForm: some View {
        Form {
            Section("Downloads") {
                LabeledContent("Default Location") {
                    HStack(spacing: 8) {
                        Text(model.downloadDirectory)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 280, alignment: .trailing)
                        Button("Choose…", action: chooseDirectory)
                    }
                }
                valueField("Concurrent Downloads", text: $model.concurrentDownloads)
                valueField("Segments per Download", text: $model.segmentsPerDownload)
                valueField("Connections per Server", text: $model.connectionsPerServer)
            }

            Section("Bandwidth") {
                valueField("Download Speed Limit", text: $model.downloadSpeedLimit, width: 120)
                valueField("Upload Speed Limit", text: $model.uploadSpeedLimit, width: 120)
                Text("Use 0 for unlimited, or values such as 500K and 2M.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("BitTorrent") {
                Toggle("Enable DHT", isOn: $model.enableDHT)
                Toggle("Enable IPv6 DHT", isOn: $model.enableDHT6)
                Toggle("Peer Exchange", isOn: $model.enablePeerExchange)
                Toggle("Local Peer Discovery", isOn: $model.enableLocalPeerDiscovery)
                Toggle("Require Encryption", isOn: $model.requireEncryption)
                valueField("Seed Ratio", text: $model.seedRatio)
                valueField("Seed Time (minutes)", text: $model.seedTimeMinutes)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }

    private func valueField(_ title: String, text: Binding<String>, width: CGFloat = 92) -> some View {
        LabeledContent(title) {
            TextField(title, text: text)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: width)
        }
    }
}

private extension NSToolbar.Identifier {
    static let preferences = Self("MoxPreferencesToolbar")
}

private extension NSToolbarItem.Identifier {
    static let cancel = Self("preferences.cancel")
    static let save = Self("preferences.save")
}
