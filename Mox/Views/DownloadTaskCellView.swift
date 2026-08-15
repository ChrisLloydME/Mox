import Cocoa

final class DownloadTaskCellView: NSTableCellView {
    private let card = NSBox()
    private let fileIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private let detailLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildInterface()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildInterface()
    }

    func configure(task: Aria2Task, isSelected: Bool) {
        titleLabel.stringValue = task.displayName
        titleLabel.toolTip = task.displayName
        detailLabel.stringValue = detailText(for: task)
        detailLabel.toolTip = detailLabel.stringValue

        progress.isIndeterminate = task.totalBytes == 0 && task.status == "active"
        progress.doubleValue = task.status == "complete" ? 100 : task.progress * 100
        if progress.isIndeterminate {
            progress.startAnimation(nil)
        } else {
            progress.stopAnimation(nil)
        }

        fileIcon.image = icon(for: task)
        card.fillColor = .controlBackgroundColor
        card.borderColor = isSelected ? .controlAccentColor : .separatorColor
        card.borderWidth = isSelected ? 2 : 1
    }

    private func buildInterface() {
        card.boxType = .custom
        card.borderWidth = 1
        card.borderColor = .separatorColor
        card.cornerRadius = 8
        card.fillColor = .controlBackgroundColor

        fileIcon.imageScaling = .scaleProportionallyUpOrDown
        fileIcon.setAccessibilityLabel("File icon")

        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1

        progress.style = .bar
        progress.controlSize = .small
        progress.minValue = 0
        progress.maxValue = 100

        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.maximumNumberOfLines = 1

        addSubview(card)
        [fileIcon, titleLabel, progress, detailLabel].forEach(card.addSubview)
        card.translatesAutoresizingMaskIntoConstraints = false
        fileIcon.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            card.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            fileIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            fileIcon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            fileIcon.widthAnchor.constraint(equalToConstant: 44),
            fileIcon.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: fileIcon.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),

            progress.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            progress.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: 5),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -8)
        ])
    }

    private func icon(for task: Aria2Task) -> NSImage {
        guard let path = task.files.first?.path, !path.isEmpty else {
            return NSWorkspace.shared.icon(forFile: task.dir)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private func detailText(for task: Aria2Task) -> String {
        switch task.status {
        case "active":
            var parts: [String] = []
            if task.totalBytes > 0 { parts.append("\(Int(task.progress * 100))%") }
            if task.bytesPerSecond > 0 { parts.append(DisplayFormat.speed(task.bytesPerSecond)) }
            if let eta = task.eta { parts.append("\(DisplayFormat.duration(eta)) remaining") }
            return parts.isEmpty ? "Starting…" : parts.joined(separator: "  •  ")
        case "complete":
            return task.totalBytes > 0 ? "Completed  •  \(DisplayFormat.size(task.totalBytes))" : "Completed"
        case "paused":
            return task.totalBytes > 0 ? "Paused  •  \(Int(task.progress * 100))%" : "Paused"
        case "waiting":
            return "Waiting"
        case "error":
            return task.errorMessage.map { "Failed  •  \($0)" } ?? "Failed"
        default:
            return task.status.capitalized
        }
    }
}
