import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = PreferencesStore()
    private let displayManager = DisplayManager()
    private let launchAtLogin = LaunchAtLoginController()

    private lazy var edgeController = DockEdgeController(
        displayManager: displayManager,
        preferences: preferences
    )

    private lazy var eventTapController = EventTapController { [weak self] _, event in
        self?.edgeController.handle(event: event) ?? event
    }

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var refreshTimer: Timer?
    private var onboardingWindowController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        syncEventTapWithProtection()
        rebuildMenu()
        showOnboardingIfNeeded()
        applyPinnedDock(after: 0.35, restoreCursor: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        refreshTimer = Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(periodicRefresh),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        eventTapController.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            if let image = NSImage(named: "StatusIcon") {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "DockPin"
            }
            button.toolTip = "DockPin"
        }
        menu.delegate = self
        statusItem?.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        edgeController.refreshAnchor(force: true)
        syncEventTapWithProtection()
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if let anchor = edgeController.currentAnchor {
            let anchorItem = NSMenuItem(title: L10n.t("menu.anchor_format", anchor.name), action: nil, keyEquivalent: "")
            anchorItem.isEnabled = false
            menu.addItem(anchorItem)
        } else {
            let anchorItem = NSMenuItem(title: L10n.t("menu.anchor_missing"), action: nil, keyEquivalent: "")
            anchorItem.isEnabled = false
            menu.addItem(anchorItem)
        }

        menu.addItem(.separator())
        menu.addItem(toggleProtectionItem())
        menu.addItem(displayPickerItem())
        menu.addItem(edgePickerItem())
        menu.addItem(widthPickerItem())
        menu.addItem(delayPickerItem())

        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem())
        menu.addItem(NSMenuItem(title: L10n.t("menu.apply_now"), action: #selector(applyPinnedDockFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.t("menu.refresh"), action: #selector(refreshDisplays), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: L10n.t("menu.open_accessibility"), action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.t("menu.show_setup_guide"), action: #selector(showOnboardingFromMenu), keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.t("menu.about"), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(quitItem())

        for item in menu.items where item.action != nil && item.target == nil {
            item.target = self
        }
    }

    private func statusLine() -> String {
        let protection = preferences.isProtectionEnabled ? L10n.t("status.protection_on") : L10n.t("status.protection_off")
        let eventTap = eventTapStatusTitle()
        return "\(protection) - \(eventTap)"
    }

    private func eventTapStatusTitle() -> String {
        if !AXIsProcessTrusted() {
            return L10n.t("status.permission_needed")
        }

        switch eventTapController.state {
        case .running:
            return L10n.t("status.event_tap_ok")
        case .unavailable:
            return L10n.t("status.event_tap_unavailable")
        case .stopped:
            return L10n.t("status.event_tap_stopped")
        }
    }

    private func toggleProtectionItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: L10n.t("menu.enable_protection"),
            action: #selector(toggleProtection),
            keyEquivalent: ""
        )
        item.state = preferences.isProtectionEnabled ? .on : .off
        return item
    }

    private func displayPickerItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("menu.display"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let displays = displayManager.displays()

        for display in displays {
            let displayItem = NSMenuItem(title: display.menuTitle, action: #selector(selectDisplay(_:)), keyEquivalent: "")
            displayItem.target = self
            displayItem.representedObject = [
                "uuid": display.uuid ?? "",
                "name": display.name
            ]
            displayItem.state = DisplayMatcher.matches(
                display: display,
                uuid: preferences.selectedDisplayUUID,
                name: preferences.selectedDisplayName
            ) || (preferences.selectedDisplayUUID == nil && preferences.selectedDisplayName == nil && display.isMain) ? .on : .off
            submenu.addItem(displayItem)
        }

        item.submenu = submenu
        return item
    }

    private func edgePickerItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("menu.edge"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for edge in DockEdge.allCases {
            let edgeItem = NSMenuItem(title: edge.localizedTitle, action: #selector(selectEdge(_:)), keyEquivalent: "")
            edgeItem.target = self
            edgeItem.representedObject = edge.rawValue
            edgeItem.state = preferences.dockEdge == edge ? .on : .off
            submenu.addItem(edgeItem)
        }

        item.submenu = submenu
        return item
    }

    private func widthPickerItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("menu.protected_width"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let options: [Double] = [0.20, 0.30, 0.40, 0.50, 0.60, 0.80, 1.00]

        for option in options {
            let title = L10n.t("menu.percent_format", Int(option * 100))
            let optionItem = NSMenuItem(title: title, action: #selector(selectProtectedWidth(_:)), keyEquivalent: "")
            optionItem.target = self
            optionItem.representedObject = option
            optionItem.state = abs(preferences.protectedWidthFraction - option) < 0.001 ? .on : .off
            submenu.addItem(optionItem)
        }

        item.submenu = submenu
        return item
    }

    private func delayPickerItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("menu.pass_through_delay"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let options: [Double] = [0.10, 0.20, 0.30, 0.45, 0.65, 0.90]

        for option in options {
            let title = L10n.t("menu.seconds_format", option)
            let optionItem = NSMenuItem(title: title, action: #selector(selectGateHold(_:)), keyEquivalent: "")
            optionItem.target = self
            optionItem.representedObject = option
            optionItem.state = abs(preferences.gateHoldDuration - option) < 0.001 ? .on : .off
            submenu.addItem(optionItem)
        }

        item.submenu = submenu
        return item
    }

    private func launchAtLoginItem() -> NSMenuItem {
        let title: String
        let state: NSControl.StateValue

        switch launchAtLogin.status {
        case .enabled:
            title = L10n.t("menu.launch_at_login")
            state = .on
        case .requiresApproval:
            title = L10n.t("menu.launch_at_login_requires_approval")
            state = .mixed
        case .disabled:
            title = L10n.t("menu.launch_at_login")
            state = .off
        case .unsupported:
            title = L10n.t("menu.launch_at_login_unsupported")
            state = .off
        }

        let item = NSMenuItem(title: title, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        item.state = state
        item.isEnabled = launchAtLogin.status != .unsupported
        return item
    }

    private func quitItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: L10n.t("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.target = NSApp
        return item
    }

    @objc private func toggleProtection() {
        preferences.isProtectionEnabled.toggle()
        syncEventTapWithProtection()
        if preferences.isProtectionEnabled {
            applyPinnedDock(after: 0.12, restoreCursor: false)
        } else {
            edgeController.resetGate()
            edgeController.nudgeSystemDefaultDock()
        }
        rebuildMenu()
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard
            let payload = sender.representedObject as? [String: String],
            let name = payload["name"]
        else {
            return
        }

        preferences.selectedDisplayUUID = payload["uuid"]?.isEmpty == false ? payload["uuid"] : nil
        preferences.selectedDisplayName = name
        edgeController.refreshAnchor(force: true)
        applyPinnedDock(after: 0.08, restoreCursor: false)
        rebuildMenu()
    }

    @objc private func selectEdge(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let edge = DockEdge(rawValue: rawValue)
        else {
            return
        }

        preferences.dockEdge = edge
        DockSystemController.setDockEdge(edge)
        syncEventTapWithProtection()
        applyPinnedDock(after: 0.70, restoreCursor: false)
        rebuildMenu()
    }

    @objc private func selectProtectedWidth(_ sender: NSMenuItem) {
        guard let width = sender.representedObject as? Double else {
            return
        }
        preferences.protectedWidthFraction = width
        rebuildMenu()
    }

    @objc private func selectGateHold(_ sender: NSMenuItem) {
        guard let delay = sender.representedObject as? Double else {
            return
        }
        preferences.gateHoldDuration = delay
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try launchAtLogin.setEnabled(launchAtLogin.status != .enabled)
        } catch {
            showError(message: L10n.t("error.launch_at_login_failed"), details: error.localizedDescription)
        }
        rebuildMenu()
    }

    @objc private func refreshDisplays() {
        edgeController.refreshAnchor(force: true)
        syncEventTapWithProtection()
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSecuritySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func applyPinnedDockFromMenu() {
        applyPinnedDock(after: 0, restoreCursor: false)
    }

    @objc private func showOnboardingFromMenu() {
        showOnboarding(markAsFirstRun: false)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DockPin"
        alert.informativeText = L10n.t("about.body")
        alert.addButton(withTitle: L10n.t("button.ok"))
        alert.runModal()
    }

    @objc private func screenParametersChanged() {
        edgeController.refreshAnchor(force: true)
        rebuildMenu()
    }

    @objc private func periodicRefresh() {
        syncEventTapWithProtection()
        edgeController.refreshAnchor()
    }

    private func showError(message: String, details: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = details
        alert.addButton(withTitle: L10n.t("button.ok"))
        alert.runModal()
    }

    private func syncEventTapWithProtection() {
        guard preferences.isProtectionEnabled, AXIsProcessTrusted() else {
            eventTapController.stop()
            return
        }

        eventTapController.retryIfNeeded()
        if eventTapController.state == .stopped {
            eventTapController.start()
        }
    }

    private func applyPinnedDock(after delay: TimeInterval, restoreCursor: Bool) {
        guard preferences.isProtectionEnabled else {
            return
        }

        syncEventTapWithProtection()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.edgeController.nudgePinnedDock(restoreCursor: restoreCursor)
        }
    }

    private func showOnboardingIfNeeded() {
        guard !preferences.hasCompletedOnboarding else {
            return
        }
        showOnboarding(markAsFirstRun: true)
    }

    private func showOnboarding(markAsFirstRun: Bool) {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(
                openSecurity: { [weak self] in self?.openSecuritySettings() },
                openAccessibility: { [weak self] in self?.openAccessibilitySettings() },
                finish: { [weak self] in
                    self?.preferences.hasCompletedOnboarding = true
                    self?.syncEventTapWithProtection()
                    self?.rebuildMenu()
                }
            )
        }

        if !markAsFirstRun {
            preferences.hasCompletedOnboarding = true
        }
        onboardingWindowController?.showWindow(nil)
    }
}
