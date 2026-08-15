import Cocoa
import UniformTypeIdentifiers

final class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate {
    private var engineManager: EngineManager!
    private var taskStore: TaskStore!
    private var settingsStore: SettingsStore!
    private var category: TaskCategory = .downloading
    private var didConfigureWindow = false
    private var visibleTasks: [Aria2Task] { taskStore?.tasks.filter { $0.category == category } ?? [] }

    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "No downloads")
    private let statusLabel = NSTextField(labelWithString: "Starting download engine…")
    private let detailController = TaskDetailViewController()
    private let categoryControl = NSSegmentedControl(labels: TaskCategory.allCases.map(\.title), trackingMode: .selectOne, target: nil, action: nil)

    func configure(engineManager: EngineManager, taskStore: TaskStore, settingsStore: SettingsStore) {
        self.engineManager = engineManager
        self.taskStore = taskStore
        self.settingsStore = settingsStore
        taskStore.onChange = { [weak self] in self?.reload() }
        engineManager.onStateChange = { [weak self] _ in self?.reload() }
        reload()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        if engineManager == nil, let app = NSApp.delegate as? AppDelegate {
            configure(engineManager: app.engineManager, taskStore: app.taskStore, settingsStore: app.settingsStore)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didConfigureWindow else { return }
        didConfigureWindow = true
        guard let window = view.window else { return }
        window.title = "Mox"
        window.setContentSize(NSSize(width: 980, height: 620))
        window.minSize = NSSize(width: 760, height: 460)
        let toolbar = NSToolbar(identifier: "MoxToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    private func buildInterface() {
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 34
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(showSelectedInFinder(_:))
        addColumn("name", title: "Name", width: 290)
        addColumn("progress", title: "Progress", width: 170)
        addColumn("speed", title: "Speed", width: 100)
        addColumn("eta", title: "ETA", width: 80)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        emptyLabel.font = .preferredFont(forTextStyle: .title2)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center

        let listContainer = NSView()
        listContainer.addSubview(scrollView)
        listContainer.addSubview(emptyLabel)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: listContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: listContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: listContainer.centerYAnchor)
        ])

        addChild(detailController)
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(listContainer)
        splitView.addArrangedSubview(detailController.view)
        listContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 430).isActive = true
        detailController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        let separator = NSBox()
        separator.boxType = .separator
        let statusBar = NSView()
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusBar.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 28)
        ])

        let stack = NSStackView(views: [splitView, separator, statusBar])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.setHuggingPriority(.defaultLow, for: .vertical)
        view = stack
    }

    private func addColumn(_ id: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        column.minWidth = 60
        tableView.addTableColumn(column)
    }

    private func reload() {
        guard isViewLoaded else { return }
        tableView.reloadData()
        emptyLabel.stringValue = "No \(category.title.lowercased()) downloads"
        emptyLabel.isHidden = !visibleTasks.isEmpty
        switch engineManager?.state {
        case .ready:
            let down = taskStore.tasks.filter { $0.category == .downloading }.reduce(0) { $0 + $1.bytesPerSecond }
            statusLabel.stringValue = "\(taskStore.tasks.count) tasks   •   \(DisplayFormat.speed(down))"
        case .starting: statusLabel.stringValue = "Starting download engine…"
        case .failed(let message): statusLabel.stringValue = "Engine unavailable: \(message)"
        default: statusLabel.stringValue = "Download engine stopped"
        }
        if let error = taskStore?.lastError { statusLabel.stringValue = "Engine communication failed: \(error)" }
        if let task = selectedTask {
            detailController.client = engineManager?.client
            detailController.task = task
        }
        view.window?.toolbar?.validateVisibleItems()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { visibleTasks.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let task = visibleTasks[row]
        let id = tableColumn?.identifier.rawValue ?? ""
        if id == "progress" {
            let progress = NSProgressIndicator()
            progress.isIndeterminate = task.totalBytes == 0 && task.status == "active"
            progress.doubleValue = task.progress * 100
            if progress.isIndeterminate { progress.startAnimation(nil) }
            let label = NSTextField(labelWithString: task.totalBytes > 0 ? "\(Int(task.progress * 100))% of \(DisplayFormat.size(task.totalBytes))" : task.status.capitalized)
            label.font = .preferredFont(forTextStyle: .caption1)
            let stack = NSStackView(views: [progress, label])
            stack.orientation = .vertical
            stack.spacing = 2
            return stack
        }
        let value: String
        switch id {
        case "speed": value = task.status == "active" ? DisplayFormat.speed(task.bytesPerSecond) : "—"
        case "eta": value = task.status == "active" ? DisplayFormat.duration(task.eta) : "—"
        default: value = task.displayName
        }
        let field = NSTextField(labelWithString: value)
        field.lineBreakMode = .byTruncatingMiddle
        field.toolTip = value
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        detailController.client = engineManager?.client
        detailController.task = row >= 0 && row < visibleTasks.count ? visibleTasks[row] : nil
    }

    @objc private func selectCategory(_ sender: NSSegmentedControl) {
        category = TaskCategory(rawValue: sender.selectedSegment) ?? .downloading
        tableView.deselectAll(nil)
        detailController.task = nil
        reload()
    }

    @IBAction func newDocument(_ sender: Any?) { addDownload(sender) }
    @IBAction func openDocument(_ sender: Any?) { addTorrent(sender) }
    @IBAction func delete(_ sender: Any?) { removeSelected(sender) }

    @objc private func addDownload(_ sender: Any?) {
        guard engineManager?.state == .ready else { return showError(RPCError(code: -30, message: "The download engine is not ready.")) }
        let sheet = AddDownloadSheet(defaultDirectory: settingsStore.value.downloadDirectory)
        sheet.begin(for: view.window!) { [weak self] text, directory in
            guard let self, let text, let directory else { return }
            Task {
                do { try await self.taskStore.add(text: text, directory: directory) }
                catch { self.showError(error) }
            }
        }
    }

    @objc private func addTorrent(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent") ?? .data]
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            Task {
                do { try await self.taskStore.addTorrent(url: url, directory: self.settingsStore.value.downloadDirectory) }
                catch { self.showError(error) }
            }
        }
    }

    @objc private func pauseSelected(_ sender: Any?) { performOnSelection { try await self.taskStore.pause($0) } }
    @objc private func resumeSelected(_ sender: Any?) { performOnSelection { try await self.taskStore.resume($0) } }

    @objc private func removeSelected(_ sender: Any?) {
        guard let task = selectedTask else { return }
        let alert = NSAlert()
        alert.messageText = "Remove “\(task.displayName)”?"
        alert.informativeText = "The task will be removed from Mox."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        let checkbox = NSButton(checkboxWithTitle: "Move downloaded files to Trash", target: nil, action: nil)
        alert.accessoryView = checkbox
        alert.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            Task {
                do { try await self.taskStore.remove(task, deleteFiles: checkbox.state == .on) }
                catch { self.showError(error) }
            }
        }
    }

    private var selectedTask: Aria2Task? {
        let row = tableView.selectedRow
        return row >= 0 && row < visibleTasks.count ? visibleTasks[row] : nil
    }

    private func performOnSelection(_ action: @escaping (Aria2Task) async throws -> Void) {
        guard let task = selectedTask else { return }
        Task { do { try await action(task) } catch { showError(error) } }
    }

    @objc private func showSelectedInFinder(_ sender: Any?) {
        guard let path = selectedTask?.files.first?.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        if let window = view.window { alert.beginSheetModal(for: window) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.add, .torrent, .pause, .resume, .remove, .flexibleSpace, .categories, .flexibleSpace, .preferences]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if id == .categories {
            categoryControl.selectedSegment = category.rawValue
            categoryControl.target = self
            categoryControl.action = #selector(selectCategory(_:))
            let item = NSToolbarItem(itemIdentifier: id)
            item.view = categoryControl
            item.label = "Task Category"
            return item
        }
        let label: String
        let symbol: String
        let action: Selector
        switch id {
        case .add: (label, symbol, action) = ("Add Download", "plus", #selector(addDownload(_:)))
        case .torrent: (label, symbol, action) = ("Add Torrent", "doc.badge.plus", #selector(addTorrent(_:)))
        case .pause: (label, symbol, action) = ("Pause", "pause", #selector(pauseSelected(_:)))
        case .resume: (label, symbol, action) = ("Resume", "play", #selector(resumeSelected(_:)))
        case .remove: (label, symbol, action) = ("Remove", "trash", #selector(removeSelected(_:)))
        case .preferences: (label, symbol, action) = ("Settings", "gearshape", #selector(AppDelegate.showPreferences(_:)))
        default: return nil
        }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.paletteLabel = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.target = id == .preferences ? NSApp.delegate : self
        item.action = action
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .add, .torrent: engineManager?.state == .ready
        case .pause: selectedTask?.canPause == true
        case .resume: selectedTask?.canResume == true
        case .remove: selectedTask != nil
        default: true
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let add = Self("add")
    static let torrent = Self("torrent")
    static let pause = Self("pause")
    static let resume = Self("resume")
    static let remove = Self("remove")
    static let categories = Self("categories")
    static let preferences = Self("preferences")
}
