import AppKit
import ApplicationServices

final class OnboardingWindowController: NSWindowController {
    private let openSecurity: () -> Void
    private let openAccessibility: () -> Void
    private let finish: () -> Void
    private let statusLabel = NSTextField(labelWithString: "")

    init(openSecurity: @escaping () -> Void, openAccessibility: @escaping () -> Void, finish: @escaping () -> Void) {
        self.openSecurity = openSecurity
        self.openAccessibility = openAccessibility
        self.finish = finish

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.t("onboarding.title")
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.contentView = makeContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        refreshPermissionStatus()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        let title = NSTextField(labelWithString: L10n.t("onboarding.heading"))
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.maximumNumberOfLines = 2
        stack.addArrangedSubview(title)

        let body = wrappingLabel(L10n.t("onboarding.body"))
        stack.addArrangedSubview(body)

        stack.addArrangedSubview(stepView(number: "1", title: L10n.t("onboarding.step_gatekeeper_title"), body: L10n.t("onboarding.step_gatekeeper_body"), buttonTitle: L10n.t("onboarding.open_security"), action: #selector(openSecuritySettings)))

        stack.addArrangedSubview(stepView(number: "2", title: L10n.t("onboarding.step_accessibility_title"), body: L10n.t("onboarding.step_accessibility_body"), buttonTitle: L10n.t("onboarding.open_accessibility"), action: #selector(openAccessibilitySettings)))

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(statusLabel)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 10
        footer.translatesAutoresizingMaskIntoConstraints = false

        let refresh = NSButton(title: L10n.t("onboarding.recheck"), target: self, action: #selector(refreshPermissionStatus))
        let done = NSButton(title: L10n.t("onboarding.done"), target: self, action: #selector(done))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        footer.addArrangedSubview(refresh)
        footer.addArrangedSubview(NSView())
        footer.addArrangedSubview(done)
        footer.setHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -24),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return root
    }

    private func stepView(number: String, title: String, body: String, buttonTitle: String, action: Selector) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12

        let badge = NSTextField(labelWithString: number)
        badge.alignment = .center
        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 10
        badge.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        badge.textColor = .white
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 22)
        ])

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(wrappingLabel(body))

        let button = NSButton(title: buttonTitle, target: self, action: action)
        textStack.addArrangedSubview(button)

        row.addArrangedSubview(badge)
        row.addArrangedSubview(textStack)
        return row
    }

    private func wrappingLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        return label
    }

    @objc private func openSecuritySettings() {
        openSecurity()
    }

    @objc private func openAccessibilitySettings() {
        openAccessibility()
    }

    @objc private func refreshPermissionStatus() {
        statusLabel.stringValue = AXIsProcessTrusted()
            ? L10n.t("onboarding.accessibility_granted")
            : L10n.t("onboarding.accessibility_missing")
    }

    @objc private func done() {
        finish()
        close()
    }
}
