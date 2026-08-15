import Cocoa

final class AboutWindowController: NSWindowController {
    init(bundle: Bundle = .main) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "About Mox"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.contentViewController = makeContentController(bundle: bundle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeContentController(bundle: Bundle) -> NSViewController {
        let controller = NSViewController()
        let root = NSView()

        let iconView = NSImageView(image: NSWorkspace.shared.icon(forFile: bundle.bundlePath))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.setAccessibilityLabel("Mox application icon")

        let nameLabel = NSTextField(labelWithString: appName(from: bundle))
        nameLabel.font = .systemFont(ofSize: 54, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1

        let versionLabel = NSTextField(labelWithString: "Version \(version(from: bundle))")
        versionLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        versionLabel.textColor = .secondaryLabelColor

        let buildLabel = NSTextField(labelWithString: "Build \(build(from: bundle))")
        buildLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        buildLabel.textColor = .tertiaryLabelColor

        let versionRow = NSStackView(views: [versionLabel, buildLabel])
        versionRow.orientation = .horizontal
        versionRow.alignment = .firstBaseline
        versionRow.spacing = 18

        let copyrightLabel = NSTextField(wrappingLabelWithString: copyrightText(from: bundle))
        copyrightLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.maximumNumberOfLines = 3

        let information = NSStackView(views: [nameLabel, versionRow, copyrightLabel])
        information.orientation = .vertical
        information.alignment = .leading
        information.spacing = 18
        information.setCustomSpacing(28, after: versionRow)

        root.addSubview(iconView)
        root.addSubview(information)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        information.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 48),
            iconView.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: 4),
            iconView.widthAnchor.constraint(equalToConstant: 184),
            iconView.heightAnchor.constraint(equalToConstant: 184),

            information.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 48),
            information.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -48),
            information.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: 2),
            nameLabel.widthAnchor.constraint(equalTo: information.widthAnchor),
            copyrightLabel.widthAnchor.constraint(equalTo: information.widthAnchor)
        ])

        controller.view = root
        return controller
    }

    private func appName(from bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Mox"
    }

    private func version(from bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func build(from bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func copyrightText(from bundle: Bundle) -> String {
        let configured = (bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let copyright = configured.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Copyright © 2026 Christopher Lloyd."
        return "\(copyright) Mox includes third-party open-source software."
    }
}
