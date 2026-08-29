import Cocoa

final class TaskDetailSheet: NSObject {
    private static let contentSize = NSSize(width: 560, height: 500)
    private let sheet: NSWindow
    private let detailController = TaskDetailViewController()
    private var completion: (() -> Void)?

    var client: Aria2Client? {
        get { detailController.client }
        set { detailController.client = newValue }
    }

    var task: Aria2Task? {
        get { detailController.task }
        set { detailController.task = newValue }
    }

    override init() {
        sheet = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        super.init()
        sheet.title = "Download Details"
        sheet.isReleasedWhenClosed = false
        let controller = buildController()
        controller.preferredContentSize = Self.contentSize
        sheet.contentViewController = controller
        sheet.setContentSize(Self.contentSize)
        sheet.contentView?.layoutSubtreeIfNeeded()
    }

    func begin(for window: NSWindow, completion: @escaping () -> Void) {
        self.completion = completion
        sheet.setContentSize(Self.contentSize)
        sheet.contentView?.layoutSubtreeIfNeeded()
        window.beginSheet(sheet)
    }

    func close() {
        guard let parent = sheet.sheetParent else { return }
        parent.endSheet(sheet)
        completion?()
        completion = nil
    }

    private func buildController() -> NSViewController {
        let controller = NSViewController()
        controller.addChild(detailController)

        let root = NSView(frame: NSRect(origin: .zero, size: Self.contentSize))
        let separator = NSBox()
        separator.boxType = .separator
        let done = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        done.keyEquivalent = "\r"

        root.addSubview(detailController.view)
        root.addSubview(separator)
        root.addSubview(done)
        detailController.view.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        done.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            detailController.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            detailController.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            detailController.view.topAnchor.constraint(equalTo: root.topAnchor),
            detailController.view.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: done.topAnchor, constant: -14),

            done.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            done.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16)
        ])
        controller.view = root
        return controller
    }

    @objc private func done(_ sender: Any?) {
        close()
    }
}
