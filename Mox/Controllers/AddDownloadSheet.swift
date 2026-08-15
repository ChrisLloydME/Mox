import Cocoa

final class AddDownloadSheet {
    private let alert = NSAlert()
    private let input = NSTextView()
    private let directoryField = NSTextField()

    init(defaultDirectory: String) {
        alert.messageText = "New Download"
        alert.informativeText = "Enter one or more HTTP, HTTPS, or Magnet links. Put each link on a separate line."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let inputScroll = NSScrollView()
        inputScroll.documentView = input
        inputScroll.hasVerticalScroller = true
        inputScroll.borderType = .bezelBorder
        input.font = .preferredFont(forTextStyle: .body)
        input.isRichText = false

        directoryField.stringValue = defaultDirectory
        directoryField.isEditable = false
        directoryField.lineBreakMode = .byTruncatingMiddle
        let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseDirectory(_:)))
        let destinationRow = NSStackView(views: [directoryField, choose])
        destinationRow.spacing = 8
        directoryField.widthAnchor.constraint(equalToConstant: 340).isActive = true

        let label = NSTextField(labelWithString: "Save to:")
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [inputScroll, label, destinationRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        inputScroll.widthAnchor.constraint(equalToConstant: 430).isActive = true
        inputScroll.heightAnchor.constraint(equalToConstant: 120).isActive = true
        alert.accessoryView = stack
    }

    func begin(for window: NSWindow, completion: @escaping (String?, String?) -> Void) {
        alert.beginSheetModal(for: window) { [self] response in
            if response == .alertFirstButtonReturn {
                completion(input.string, directoryField.stringValue)
            } else {
                completion(nil, nil)
            }
        }
    }

    @objc private func chooseDirectory(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: directoryField.stringValue)
        panel.begin { [weak self] response in
            if response == .OK, let path = panel.url?.path { self?.directoryField.stringValue = path }
        }
    }
}
