import Cocoa

final class TaskDetailViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var client: Aria2Client?
    var task: Aria2Task? { didSet { update() } }

    private let titleLabel = NSTextField(labelWithString: "No Selection")
    private let summaryLabel = NSTextField(wrappingLabelWithString: "Select a task to see its details.")
    private let locationLabel = NSTextField(wrappingLabelWithString: "")
    private let filesTable = NSTableView()
    private let peersTable = NSTableView()
    private let trackersView = NSTextView()
    private var files: [Aria2File] = []
    private var peers: [Aria2Peer] = []

    override func loadView() {
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.textColor = .secondaryLabelColor
        locationLabel.textColor = .secondaryLabelColor
        locationLabel.font = .preferredFont(forTextStyle: .caption1)

        configure(table: filesTable, columns: [("file", "File", 190), ("size", "Size", 80)])
        configure(table: peersTable, columns: [("peer", "Peer", 140), ("speed", "Down", 80)])
        let filesScroll = scrollView(for: filesTable)
        let peersScroll = scrollView(for: peersTable)
        let trackerScroll = NSScrollView()
        trackerScroll.documentView = trackersView
        trackerScroll.hasVerticalScroller = true
        trackersView.isEditable = false
        trackersView.drawsBackground = false
        trackersView.font = .preferredFont(forTextStyle: .body)

        let tabs = NSTabView()
        tabs.addTabViewItem(item(label: "Files", view: filesScroll))
        tabs.addTabViewItem(item(label: "Peers", view: peersScroll))
        tabs.addTabViewItem(item(label: "Trackers", view: trackerScroll))

        let stack = NSStackView(views: [titleLabel, summaryLabel, locationLabel, tabs])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        tabs.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true
        tabs.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        view = stack
    }

    private func configure(table: NSTableView, columns: [(String, String, CGFloat)]) {
        table.delegate = self
        table.dataSource = self
        table.usesAlternatingRowBackgroundColors = true
        for (id, title, width) in columns {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
    }

    private func scrollView(for table: NSTableView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        return scroll
    }

    private func item(label: String, view: NSView) -> NSTabViewItem {
        let result = NSTabViewItem()
        result.label = label
        result.view = view
        return result
    }

    private func update() {
        guard isViewLoaded else { return }
        guard let task else {
            titleLabel.stringValue = "No Selection"
            summaryLabel.stringValue = "Select a task to see its details."
            locationLabel.stringValue = ""
            files = []
            peers = []
            trackersView.string = ""
            filesTable.reloadData()
            peersTable.reloadData()
            return
        }
        titleLabel.stringValue = task.displayName
        let progress = task.totalBytes > 0 ? "\(Int(task.progress * 100))% • \(DisplayFormat.size(task.completedBytes)) of \(DisplayFormat.size(task.totalBytes))" : task.status.capitalized
        let error = task.errorMessage.map { "\n\($0)" } ?? ""
        summaryLabel.stringValue = "\(task.status.capitalized) • \(progress)\(error)"
        locationLabel.stringValue = task.dir
        files = task.files
        let trackers = task.bittorrent?.announceList?.flatMap { $0 } ?? []
        trackersView.string = trackers.isEmpty ? "No tracker information is available for this task." : trackers.joined(separator: "\n")
        filesTable.reloadData()
        peers = []
        peersTable.reloadData()
        guard let client, task.infoHash != nil else { return }
        let gid = task.gid
        Task { [weak self] in
            let result = (try? await client.peers(gid: gid)) ?? []
            guard self?.task?.gid == gid else { return }
            self?.peers = result
            self?.peersTable.reloadData()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { tableView === filesTable ? files.count : peers.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = tableColumn?.identifier.rawValue
        let text: String
        if tableView === filesTable {
            let file = files[row]
            text = id == "size" ? DisplayFormat.size(Int64(file.length) ?? 0) : URL(fileURLWithPath: file.path).lastPathComponent
        } else {
            let peer = peers[row]
            text = id == "speed" ? DisplayFormat.speed(Int64(peer.downloadSpeed) ?? 0) : "\(peer.ip):\(peer.port)"
        }
        let field = NSTextField(labelWithString: text)
        field.lineBreakMode = .byTruncatingMiddle
        field.toolTip = text
        return field
    }
}
