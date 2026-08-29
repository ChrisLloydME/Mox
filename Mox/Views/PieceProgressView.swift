import Cocoa

final class PieceProgressView: NSView {
    private enum Metrics {
        static let blockSize: CGFloat = 7
        static let spacing: CGFloat = 2
        static let cornerRadius: CGFloat = 1.5
        static let maximumColumns = 48
        static let maximumRows = 12
    }

    private var states: [Bool]?
    private var hasRendered = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func update(states: [Bool]?) {
        guard !hasRendered || states != self.states else { return }
        hasRendered = true
        self.states = states
        updateAccessibilityValue()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let states, !states.isEmpty else {
            drawPlaceholder()
            return
        }

        let columns = Self.columnCount(for: bounds.width)
        let rows = Self.rowCount(for: bounds.height)
        let ratios = aggregate(states: states, maximumBlocks: columns * rows)
        guard !ratios.isEmpty else { return }

        let usedColumns = min(columns, ratios.count)
        let usedRows = Int(ceil(Double(ratios.count) / Double(columns)))
        let gridWidth = CGFloat(usedColumns) * Metrics.blockSize + CGFloat(max(0, usedColumns - 1)) * Metrics.spacing
        let gridHeight = CGFloat(usedRows) * Metrics.blockSize + CGFloat(max(0, usedRows - 1)) * Metrics.spacing
        let origin = CGPoint(
            x: max(0, (bounds.width - gridWidth) / 2),
            y: max(0, (bounds.height - gridHeight) / 2)
        )

        for (index, ratio) in ratios.enumerated() {
            let column = index % columns
            let row = index / columns
            let rect = NSRect(
                x: origin.x + CGFloat(column) * (Metrics.blockSize + Metrics.spacing),
                y: origin.y + CGFloat(row) * (Metrics.blockSize + Metrics.spacing),
                width: Metrics.blockSize,
                height: Metrics.blockSize
            )
            color(for: ratio).setFill()
            NSBezierPath(roundedRect: rect, xRadius: Metrics.cornerRadius, yRadius: Metrics.cornerRadius).fill()
        }
    }

    static func columnCount(for width: CGFloat) -> Int {
        fittedCount(for: width, maximum: Metrics.maximumColumns)
    }

    static func rowCount(for height: CGFloat) -> Int {
        fittedCount(for: height, maximum: Metrics.maximumRows)
    }

    private static func fittedCount(for length: CGFloat, maximum: Int) -> Int {
        let count = Int((max(0, length) + Metrics.spacing) / (Metrics.blockSize + Metrics.spacing))
        return min(maximum, max(1, count))
    }

    private func configure() {
        needsDisplay = true
        postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: self
        )
        setAccessibilityRole(.progressIndicator)
        setAccessibilityHelp("Shows which pieces of the download are complete.")
    }

    @objc private func frameDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    private func updateAccessibilityValue() {
        guard let states, !states.isEmpty else {
            setAccessibilityValue("Unavailable")
            return
        }
        let completed = states.filter { $0 }.count
        setAccessibilityValue("\(completed) of \(states.count) pieces complete")
    }

    private func drawPlaceholder() {
        let text = "Piece map is unavailable for this download."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .paragraphStyle: centeredParagraphStyle()
        ]
        let insetBounds = bounds.insetBy(dx: 12, dy: 0)
        let height = (text as NSString).boundingRect(
            with: NSSize(width: insetBounds.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        ).height
        let rect = NSRect(x: insetBounds.minX, y: max(0, (bounds.height - height) / 2), width: insetBounds.width, height: height)
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attributes)
    }

    private func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }

    private func aggregate(states: [Bool], maximumBlocks: Int) -> [Double] {
        let blockCount = min(maximumBlocks, states.count)
        guard blockCount > 0 else { return [] }
        return (0..<blockCount).map { block in
            let start = block * states.count / blockCount
            let end = max(start + 1, (block + 1) * states.count / blockCount)
            let upperBound = min(end, states.count)
            let completed = states[start..<upperBound].filter { $0 }.count
            return Double(completed) / Double(upperBound - start)
        }
    }

    private func color(for ratio: Double) -> NSColor {
        if ratio == 0 { return .separatorColor.withAlphaComponent(0.28) }
        return .systemGreen.withAlphaComponent(0.4 + ratio * 0.6)
    }
}
