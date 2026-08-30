import Cocoa
import UniformTypeIdentifiers

final class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate {
    private var engineManager: EngineManager!
    private var taskStore: TaskStore!
    private var settingsStore: SettingsStore!
    private var didConfigureWindow = false
    private var selectedTaskIDs: Set<String> = []
    private var visibleTasks: [Aria2Task] { taskStore?.tasks ?? [] }

    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "No downloads")
    private var addDownloadSheet: AddDownloadSheet?
    private var detailSheet: TaskDetailSheet?

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
        window.setContentSize(NSSize(width: 820, height: 560))
        window.minSize = NSSize(width: 640, height: 420)
        let toolbar = NSToolbar(identifier: "MoxToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    private func buildInterface() {
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = true
        tableView.selectionHighlightStyle = .none
        tableView.headerView = nil
        tableView.rowHeight = 82
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .windowBackgroundColor
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(showDetails(_:))
        let taskColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("task"))
        taskColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(taskColumn)

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

        let rootView = NSView()
        rootView.addSubview(listContainer)
        listContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listContainer.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            listContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            listContainer.topAnchor.constraint(equalTo: rootView.topAnchor),
            listContainer.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
        view = rootView
    }

    private func reload() {
        guard isViewLoaded else { return }
        tableView.reloadData()
        selectedTaskIDs.formIntersection(visibleTasks.map(\.gid))
        let selectedRows = IndexSet(visibleTasks.indices.filter { selectedTaskIDs.contains(visibleTasks[$0].gid) })
        if selectedRows.isEmpty {
            tableView.deselectAll(nil)
            detailSheet?.close()
            detailSheet = nil
        } else {
            tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
        }
        emptyLabel.stringValue = "No downloads"
        emptyLabel.isHidden = !visibleTasks.isEmpty
        detailSheet?.client = engineManager?.client
        detailSheet?.task = selectedTask
        view.window?.toolbar?.validateVisibleItems()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { visibleTasks.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let task = visibleTasks[row]
        let cell = DownloadTaskCellView()
        cell.configure(
            task: task,
            isSelected: selectedTaskIDs.contains(task.gid)
        )
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedTaskIDs = Set(tableView.selectedRowIndexes.compactMap { row in
            row < visibleTasks.count ? visibleTasks[row].gid : nil
        })
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        for visibleRow in visibleRows.location..<(visibleRows.location + visibleRows.length) {
            guard let cell = tableView.view(atColumn: 0, row: visibleRow, makeIfNecessary: false) as? DownloadTaskCellView else { continue }
            let task = visibleTasks[visibleRow]
            cell.configure(
                task: task,
                isSelected: selectedTaskIDs.contains(task.gid)
            )
        }
        if let detailSheet {
            if let selectedTask {
                detailSheet.task = selectedTask
            } else {
                detailSheet.close()
                self.detailSheet = nil
            }
        }
        view.window?.toolbar?.validateVisibleItems()
    }

    @IBAction func newDocument(_ sender: Any?) { addDownload(sender) }
    @IBAction func openDocument(_ sender: Any?) { addTorrent(sender) }
    @IBAction func delete(_ sender: Any?) { removeSelected(sender) }

    @objc private func addDownload(_ sender: Any?) {
        guard engineManager?.state == .ready else { return showError(RPCError(code: -30, message: "The download engine is not ready.")) }
        let sheet = AddDownloadSheet(
            defaultDirectory: settingsStore.value.downloadDirectory,
            defaultSplit: settingsStore.value.split
        )
        addDownloadSheet = sheet
        sheet.begin(for: view.window!) { [weak self] text, directory, split in
            guard let self else { return }
            self.addDownloadSheet = nil
            guard let text, let directory, let split else { return }
            Task {
                do { try await self.taskStore.add(text: text, directory: directory, split: split) }
                catch { self.showError(error) }
            }
        }
    }

    @objc private func addTorrent(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent") ?? .data]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            Task {
                do { try await self.taskStore.addTorrent(url: url, directory: self.settingsStore.value.downloadDirectory) }
                catch { self.showError(error) }
            }
        }
    }

    @objc private func pauseSelected(_ sender: Any?) {
        performOnSelectedTasks(where: \.canPause) { try await self.taskStore.pause($0) }
    }

    @objc private func resumeSelected(_ sender: Any?) {
        performOnSelectedTasks(where: \.canResume) { try await self.taskStore.resume($0) }
    }

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

    private var selectedTasks: [Aria2Task] {
        visibleTasks.filter { selectedTaskIDs.contains($0.gid) }
    }

    private var selectedTask: Aria2Task? {
        selectedTasks.count == 1 ? selectedTasks[0] : nil
    }

    private func performOnSelectedTasks(
        where predicate: (Aria2Task) -> Bool,
        action: @escaping ([Aria2Task]) async throws -> Void
    ) {
        let tasks = selectedTasks.filter(predicate)
        guard !tasks.isEmpty else { return }
        Task { do { try await action(tasks) } catch { showError(error) } }
    }

    @objc private func showSelectedInFinder(_ sender: Any?) {
        guard let path = selectedTask?.files.first?.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @objc private func showDetails(_ sender: Any?) {
        guard let task = selectedTask else { return }
        guard detailSheet == nil, let window = view.window else { return }

        let sheet = TaskDetailSheet()
        sheet.client = engineManager?.client
        sheet.task = task
        detailSheet = sheet
        sheet.begin(for: window) { [weak self] in
            self?.detailSheet = nil
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        if let window = view.window { alert.beginSheetModal(for: window) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.add, .torrent, .flexibleSpace, .pause, .resume, .details, .remove]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let label: String
        let symbol: String
        let action: Selector
        switch id {
        case .add: (label, symbol, action) = ("Add Download", "plus", #selector(addDownload(_:)))
        case .torrent: (label, symbol, action) = ("Add Torrent", "doc.badge.plus", #selector(addTorrent(_:)))
        case .details: (label, symbol, action) = ("Details", "info.circle", #selector(showDetails(_:)))
        case .pause: (label, symbol, action) = ("Pause", "pause", #selector(pauseSelected(_:)))
        case .resume: (label, symbol, action) = ("Resume", "play", #selector(resumeSelected(_:)))
        case .remove: (label, symbol, action) = ("Remove", "trash", #selector(removeSelected(_:)))
        default: return nil
        }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.paletteLabel = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.target = self
        item.action = action
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .add, .torrent: engineManager?.state == .ready
        case .pause: selectedTasks.contains(where: \.canPause)
        case .resume: selectedTasks.contains(where: \.canResume)
        case .details: selectedTask != nil
        case .remove: !selectedTasks.isEmpty
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
    static let details = Self("details")
}
