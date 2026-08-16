import Cocoa

final class PieceProgressView: NSView {
    private let placeholder = NSTextField(labelWithString: "Piece map is unavailable for this download.")
    private var grid: NSStackView?
    private var lastStates: [Bool]?
    private var hasRendered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configurePlaceholder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configurePlaceholder()
    }

    func update(states: [Bool]?) {
        guard !hasRendered || states != lastStates else { return }
        hasRendered = true
        lastStates = states
        grid?.removeFromSuperview()
        grid = nil

        guard let states, !states.isEmpty else {
            placeholder.isHidden = false
            return
        }
        placeholder.isHidden = true

        let columns = 48
        let ratios = aggregate(states: states, maximumBlocks: columns * 12)
        let rows = stride(from: 0, to: ratios.count, by: columns).map { start -> NSStackView in
            let end = min(start + columns, ratios.count)
            let blocks = ratios[start..<end].map(block(for:))
            let row = NSStackView(views: blocks)
            row.orientation = .horizontal
            row.spacing = 2
            return row
        }
        let grid = NSStackView(views: rows)
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 2
        addSubview(grid)
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: centerYAnchor),
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
        self.grid = grid
    }

    private func configurePlaceholder() {
        placeholder.textColor = .tertiaryLabelColor
        placeholder.alignment = .center
        addSubview(placeholder)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholder.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            placeholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])
    }

    private func aggregate(states: [Bool], maximumBlocks: Int) -> [Double] {
        let blockCount = min(maximumBlocks, states.count)
        guard blockCount > 0 else { return [] }
        return (0..<blockCount).map { block in
            let start = block * states.count / blockCount
            let end = max(start + 1, (block + 1) * states.count / blockCount)
            let completed = states[start..<min(end, states.count)].filter { $0 }.count
            return Double(completed) / Double(min(end, states.count) - start)
        }
    }

    private func block(for ratio: Double) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = 1.5
        if ratio == 0 {
            box.fillColor = .separatorColor.withAlphaComponent(0.28)
        } else {
            box.fillColor = .systemGreen.withAlphaComponent(0.4 + ratio * 0.6)
        }
        box.widthAnchor.constraint(equalToConstant: 7).isActive = true
        box.heightAnchor.constraint(equalToConstant: 7).isActive = true
        box.toolTip = ratio == 1 ? "Completed" : ratio == 0 ? "Not downloaded" : "Partially completed"
        return box
    }
}
