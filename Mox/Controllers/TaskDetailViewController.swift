import Cocoa

final class TaskDetailViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    static let initialContentSize = NSSize(width: 520, height: 420)
    var client: Aria2Client?
    var task: Aria2Task? { didSet { update() } }

    private let titleLabel = NSTextField(labelWithString: "No Selection")
    private let summaryLabel = NSTextField(wrappingLabelWithString: "Select a task to see its details.")
    private let locationLabel = NSTextField(wrappingLabelWithString: "")
    private let pieceProgressView = PieceProgressView()
    private let progressIndicator = NSProgressIndicator()
    private let progressLabel = NSTextField(labelWithString: "0%")
    private let transferLabel = NSTextField(labelWithString: "")
    private let activityLabel = NSTextField(labelWithString: "")
    private let filesTable = NSTableView()
    private let peersTable = NSTableView()
    private let trackersView = NSTextView()
    private var files: [Aria2File] = []
    private var peers: [Aria2Peer] = []

    override func loadView() {
        let rootView = NSView(frame: NSRect(origin: .zero, size: Self.initialContentSize))
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.textColor = .secondaryLabelColor
        locationLabel.textColor = .secondaryLabelColor
        locationLabel.font = .preferredFont(forTextStyle: .caption1)
        locationLabel.lineBreakMode = .byTruncatingMiddle
        locationLabel.maximumNumberOfLines = 1

        configure(table: filesTable, columns: [("file", "File", 340), ("size", "Size", 100)])
        configure(table: peersTable, columns: [("peer", "Peer", 300), ("speed", "Down", 120)])
        let filesScroll = scrollView(for: filesTable)
        let peersScroll = scrollView(for: peersTable)
        let trackerScroll = NSScrollView()
        trackerScroll.documentView = trackersView
        trackerScroll.hasVerticalScroller = true
        trackerScroll.autohidesScrollers = true
        trackersView.isEditable = false
        trackersView.drawsBackground = false
        trackersView.font = .preferredFont(forTextStyle: .body)
        trackersView.textContainerInset = NSSize(width: 8, height: 8)

        let overview = buildOverview()
        let tabs = NSTabView(frame: NSRect(x: 12, y: 12, width: 496, height: 300))
        tabs.addTabViewItem(item(label: "Overview", view: overview))
        tabs.addTabViewItem(item(label: "Files", view: filesScroll))
        tabs.addTabViewItem(item(label: "Peers", view: peersScroll))
        tabs.addTabViewItem(item(label: "Trackers", view: trackerScroll))

        let header = NSStackView(views: [titleLabel, summaryLabel, locationLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 5

        rootView.addSubview(header)
        rootView.addSubview(tabs)
        header.translatesAutoresizingMaskIntoConstraints = false
        tabs.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -16),
            header.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 16),
            titleLabel.widthAnchor.constraint(equalTo: header.widthAnchor),
            summaryLabel.widthAnchor.constraint(equalTo: header.widthAnchor),
            locationLabel.widthAnchor.constraint(equalTo: header.widthAnchor),
            tabs.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            tabs.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            tabs.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            tabs.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12)
        ])
        preferredContentSize = Self.initialContentSize
        view = rootView
    }

    private func buildOverview() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 496, height: 280))
        pieceProgressView.setAccessibilityLabel("Download pieces")

        progressIndicator.style = .bar
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressLabel.alignment = .right
        progressLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        progressLabel.setContentHuggingPriority(.required, for: .horizontal)

        let progressTitle = NSTextField(labelWithString: "Progress:")
        progressTitle.setContentHuggingPriority(.required, for: .horizontal)
        let progressRow = NSStackView(views: [progressTitle, progressIndicator, progressLabel])
        progressRow.spacing = 10
        progressRow.alignment = .centerY

        transferLabel.alignment = .center
        transferLabel.textColor = .secondaryLabelColor
        activityLabel.alignment = .center
        activityLabel.textColor = .secondaryLabelColor

        let content = NSStackView(views: [pieceProgressView, progressRow, transferLabel, activityLabel])
        content.orientation = .vertical
        content.spacing = 14
        root.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        let overviewConstraints = [
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -16),
            pieceProgressView.heightAnchor.constraint(equalToConstant: 118),
            progressRow.widthAnchor.constraint(equalTo: content.widthAnchor),
            transferLabel.widthAnchor.constraint(equalTo: content.widthAnchor),
            activityLabel.widthAnchor.constraint(equalTo: content.widthAnchor)
        ]
        overviewConstraints.forEach { $0.priority = NSLayoutConstraint.Priority(999) }
        NSLayoutConstraint.activate(overviewConstraints)
        return root
    }

    private func configure(table: NSTableView, columns: [(String, String, CGFloat)]) {
        table.delegate = self
        table.dataSource = self
        table.usesAlternatingRowBackgroundColors = false
        table.rowHeight = 28
        for (id, title, width) in columns {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            column.minWidth = id == "file" || id == "peer" ? 180 : 80
            if id == "file" || id == "peer" { column.resizingMask = .autoresizingMask }
            table.addTableColumn(column)
        }
    }

    private func scrollView(for table: NSTableView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
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
            pieceProgressView.update(states: nil)
            progressIndicator.doubleValue = 0
            progressLabel.stringValue = "0%"
            transferLabel.stringValue = ""
            activityLabel.stringValue = ""
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
        pieceProgressView.update(states: task.pieceStates)
        let percent = task.status == "complete" ? 100 : Int(task.progress * 100)
        progressIndicator.isIndeterminate = task.totalBytes == 0 && task.status == "active"
        progressIndicator.doubleValue = Double(percent)
        if progressIndicator.isIndeterminate {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
        progressLabel.stringValue = "\(percent)%"
        if task.totalBytes > 0 {
            var transfer = "\(DisplayFormat.size(task.completedBytes)) / \(DisplayFormat.size(task.totalBytes))"
            if let eta = task.eta { transfer += "   •   \(DisplayFormat.duration(eta)) remaining" }
            transferLabel.stringValue = transfer
        } else {
            transferLabel.stringValue = task.status.capitalized
        }
        let connections = task.connections ?? "0"
        let seeders = task.numSeeders ?? "—"
        let pieceSize: String
        if let bytes = task.pieceLength.flatMap(Int64.init) {
            pieceSize = DisplayFormat.size(bytes)
        } else {
            pieceSize = "—"
        }
        activityLabel.stringValue = "Connections: \(connections)   •   Seeders: \(seeders)   •   Piece size: \(pieceSize)"
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
