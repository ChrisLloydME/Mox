import Cocoa

final class AddDownloadSheet: NSObject {
    private let sheet: NSWindow
    private let input = NSTextView()
    private let directoryField = NSTextField()
    private let splitField = NSTextField()
    private let splitStepper = NSStepper()
    private var completion: ((String?, String?, Int?) -> Void)?

    init(defaultDirectory: String, defaultSplit: Int) {
        sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        super.init()
        sheet.title = "New Download"
        sheet.isReleasedWhenClosed = false
        sheet.contentView = buildContent(defaultDirectory: defaultDirectory, defaultSplit: defaultSplit)
    }

    func begin(for window: NSWindow, completion: @escaping (String?, String?, Int?) -> Void) {
        self.completion = completion
        window.beginSheet(sheet)
        sheet.makeFirstResponder(input)
    }

    private func buildContent(defaultDirectory: String, defaultSplit: Int) -> NSView {
        let root = NSView()

        let instructions = NSTextField(wrappingLabelWithString: "Enter one or more HTTP, HTTPS, or Magnet links. Put each link on a separate line.")
        instructions.textColor = .secondaryLabelColor

        let inputScroll = NSScrollView()
        inputScroll.documentView = input
        inputScroll.hasVerticalScroller = true
        inputScroll.autohidesScrollers = true
        inputScroll.borderType = .bezelBorder
        input.font = .preferredFont(forTextStyle: .body)
        input.isRichText = false
        input.isAutomaticQuoteSubstitutionEnabled = false
        input.isAutomaticDashSubstitutionEnabled = false
        input.textContainerInset = NSSize(width: 6, height: 6)

        directoryField.stringValue = defaultDirectory
        directoryField.isEditable = false
        directoryField.lineBreakMode = .byTruncatingMiddle
        directoryField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseDirectory(_:)))
        choose.setContentHuggingPriority(.required, for: .horizontal)
        let destinationRow = NSStackView(views: [directoryField, choose])
        destinationRow.spacing = 8

        let splitValue = min(64, max(1, defaultSplit))
        splitField.integerValue = splitValue
        splitField.alignment = .right
        splitField.formatter = integerFormatter()
        splitField.target = self
        splitField.action = #selector(editSplit(_:))
        splitStepper.minValue = 1
        splitStepper.maxValue = 64
        splitStepper.increment = 1
        splitStepper.integerValue = splitValue
        splitStepper.target = self
        splitStepper.action = #selector(stepSplit(_:))
        let splitRow = NSStackView(views: [splitField, splitStepper])
        splitRow.spacing = 4
        splitField.widthAnchor.constraint(equalToConstant: 54).isActive = true

        let form = NSGridView(views: [
            [fieldLabel("Save to:"), destinationRow],
            [fieldLabel("Threads:"), splitRow]
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).xPlacement = .fill
        form.rowSpacing = 10
        form.columnSpacing = 10

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let add = NSButton(title: "Add", target: self, action: #selector(add(_:)))
        add.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, add])
        buttons.spacing = 8

        [instructions, inputScroll, form, buttons].forEach {
            root.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            instructions.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            instructions.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            instructions.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),

            inputScroll.leadingAnchor.constraint(equalTo: instructions.leadingAnchor),
            inputScroll.trailingAnchor.constraint(equalTo: instructions.trailingAnchor),
            inputScroll.topAnchor.constraint(equalTo: instructions.bottomAnchor, constant: 14),
            inputScroll.heightAnchor.constraint(equalToConstant: 170),

            form.leadingAnchor.constraint(equalTo: instructions.leadingAnchor),
            form.trailingAnchor.constraint(equalTo: instructions.trailingAnchor),
            form.topAnchor.constraint(equalTo: inputScroll.bottomAnchor, constant: 16),

            buttons.trailingAnchor.constraint(equalTo: instructions.trailingAnchor),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: form.bottomAnchor, constant: 18),
            buttons.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])
        return root
    }

    private func fieldLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    private func integerFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 64
        formatter.allowsFloats = false
        return formatter
    }

    @objc private func stepSplit(_ sender: NSStepper) {
        splitField.integerValue = sender.integerValue
    }

    @objc private func editSplit(_ sender: NSTextField) {
        let value = min(64, max(1, sender.integerValue))
        sender.integerValue = value
        splitStepper.integerValue = value
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

    @objc private func add(_ sender: Any?) {
        let split = splitField.integerValue
        guard (1...64).contains(split) else {
            NSSound.beep()
            sheet.makeFirstResponder(splitField)
            return
        }
        finish(response: .OK, text: input.string, directory: directoryField.stringValue, split: split)
    }

    @objc private func cancel(_ sender: Any?) {
        finish(response: .cancel, text: nil, directory: nil, split: nil)
    }

    private func finish(response: NSApplication.ModalResponse, text: String?, directory: String?, split: Int?) {
        guard let parent = sheet.sheetParent else { return }
        parent.endSheet(sheet, returnCode: response)
        completion?(text, directory, split)
        completion = nil
    }
}
