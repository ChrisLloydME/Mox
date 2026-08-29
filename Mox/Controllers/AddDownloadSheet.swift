import Cocoa
import Combine
import SwiftUI

final class AddDownloadSheet: NSObject {
    private let sheet: NSWindow
    private let input = NSTextView()
    private let optionsModel: AddDownloadOptionsModel
    private var completion: ((String?, String?, Int?) -> Void)?

    init(defaultDirectory: String, defaultSplit: Int) {
        optionsModel = AddDownloadOptionsModel(directory: defaultDirectory, threads: defaultSplit)
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

        let options = NSHostingView(rootView: AddDownloadOptionsView(
            model: optionsModel,
            chooseDirectory: { [weak self] in self?.chooseDirectory() }
        ))

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let add = NSButton(title: "Add", target: self, action: #selector(add(_:)))
        add.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, add])
        buttons.spacing = 8

        [instructions, inputScroll, options, buttons].forEach {
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

            options.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            options.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            options.topAnchor.constraint(equalTo: inputScroll.bottomAnchor, constant: 6),
            options.heightAnchor.constraint(equalToConstant: 132),

            buttons.trailingAnchor.constraint(equalTo: instructions.trailingAnchor),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: options.bottomAnchor, constant: 10),
            buttons.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])
        return root
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: optionsModel.directory)
        panel.begin { [weak self] response in
            if response == .OK, let path = panel.url?.path { self?.optionsModel.directory = path }
        }
    }

    @objc private func add(_ sender: Any?) {
        let split = optionsModel.threads
        guard (1...64).contains(split) else {
            NSSound.beep()
            return
        }
        finish(response: .OK, text: input.string, directory: optionsModel.directory, split: split)
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

final class AddDownloadOptionsModel: ObservableObject {
    @Published var directory: String
    @Published private(set) var threads: Int

    init(directory: String, threads: Int) {
        self.directory = directory
        self.threads = min(64, max(1, threads))
    }

    func setThreadCount(_ value: Int) {
        threads = min(64, max(1, value))
    }
}

private struct AddDownloadOptionsView: View {
    @ObservedObject var model: AddDownloadOptionsModel
    let chooseDirectory: () -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent("Save to") {
                    HStack(spacing: 8) {
                        TextField("Save to", text: $model.directory)
                            .labelsHidden()
                            .frame(minWidth: 260)
                        Button("Choose…", action: chooseDirectory)
                    }
                }
                LabeledContent("Threads") {
                    HStack(spacing: 10) {
                        Slider(
                            value: Binding(
                                get: { Double(model.threads) },
                                set: { model.setThreadCount(Int($0.rounded())) }
                            ),
                            in: 1...64
                        )
                        .frame(minWidth: 230)
                        .accessibilityLabel("Download threads")
                        .accessibilityValue("\(model.threads)")

                        Text(model.threads.formatted())
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 26, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
