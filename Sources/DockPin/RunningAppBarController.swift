import AppKit
import CoreGraphics

private final class DockBackdropView: NSVisualEffectView {
    private let tintView = NSView()
    private var lastMaskSize: NSSize = .zero
    private var lastMaskRadius: CGFloat = 0

    var dockCornerRadius: CGFloat = 18 {
        didSet {
            needsLayout = true
        }
    }

    var tintColor: NSColor = .clear {
        didSet {
            tintView.layer?.backgroundColor = tintColor.cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tintView.frame = bounds
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        addSubview(tintView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        tintView.frame = bounds
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        addSubview(tintView)
    }

    override func layout() {
        super.layout()
        wantsLayer = true
        layer?.cornerRadius = dockCornerRadius
        layer?.cornerCurve = .continuous
        layer?.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
        layer?.masksToBounds = true
        tintView.layer?.cornerRadius = dockCornerRadius
        tintView.layer?.cornerCurve = .continuous
        tintView.layer?.maskedCorners = layer?.maskedCorners ?? []
        tintView.layer?.masksToBounds = true

        if bounds.size != lastMaskSize || dockCornerRadius != lastMaskRadius {
            let radius = dockCornerRadius
            let image = NSImage(size: bounds.size, flipped: false) { rect in
                NSColor.white.setFill()
                NSBezierPath(
                    roundedRect: rect,
                    xRadius: radius,
                    yRadius: radius
                ).fill()
                return true
            }
            maskImage = image
            lastMaskSize = bounds.size
            lastMaskRadius = dockCornerRadius
        }
    }
}

final class RunningAppBarController {
    private struct Bar {
        let displayID: CGDirectDisplayID
        let screen: NSScreen
        let panel: NSPanel
        let effect: DockBackdropView
        let stack: NSStackView
    }

    private let pollInterval: TimeInterval = 0.08
    private let revealDelay: TimeInterval = 0.18
    private let hideDelay: TimeInterval = 0.35
    private let triggerMinY: CGFloat = 4
    private let triggerMaxY: CGFloat = 88
    private let horizontalTriggerInset: CGFloat = 48
    private let panelBottomInset: CGFloat = 16
    private let initialPanelHeight: CGFloat = 72
    private let minimumIconSize: CGFloat = 46
    private let iconSlotPadding: CGFloat = 4
    private let iconSpacing: CGFloat = 4
    private let panelHorizontalPadding: CGFloat = 10
    private let panelVerticalPadding: CGFloat = 11
    private let indicatorSize: CGFloat = 4
    private let indicatorGap: CGFloat = 3
    private let backdropTintAlpha: CGFloat = 0.30
    private let backdropBorderAlpha: CGFloat = 0.28

    private var isEnabled = false
    private var targetDisplayID: CGDirectDisplayID?
    private var bars: [CGDirectDisplayID: Bar] = [:]
    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var revealCandidateID: CGDirectDisplayID?
    private var revealCandidateStartedAt: TimeInterval?
    private var visibleDisplayID: CGDirectDisplayID?
    private var outsideStartedAt: TimeInterval?
    private var previewVisibleUntil: TimeInterval?

    var diagnosticSummary: String {
        "enabled=\(isEnabled),bars=\(bars.count),timer=\(pollTimer != nil),visibleDisplay=\(visibleDisplayID.map(String.init) ?? "none")"
    }

    var isPresentingBarForDiagnostics: Bool {
        guard let visibleDisplayID, let bar = bars[visibleDisplayID] else {
            return false
        }
        return bar.panel.isVisible
    }

    var visiblePanelFrameForDiagnostics: NSRect? {
        guard let visibleDisplayID else {
            return nil
        }
        return bars[visibleDisplayID]?.panel.frame
    }

    func setEnabled(_ enabled: Bool, targetDisplayID: CGDirectDisplayID?) {
        let targetChanged = self.targetDisplayID != targetDisplayID
        self.targetDisplayID = targetDisplayID

        if enabled != isEnabled {
            isEnabled = enabled
            enabled ? start() : stop()
        } else if enabled && targetChanged {
            refreshScreens()
        }
    }

    func refreshScreens(targetDisplayID: CGDirectDisplayID?) {
        self.targetDisplayID = targetDisplayID
        guard isEnabled else {
            return
        }
        refreshScreens()
    }

    func stop() {
        isEnabled = false
        pollTimer?.invalidate()
        pollTimer = nil

        let notificationCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        for bar in bars.values {
            bar.panel.orderOut(nil)
        }
        bars.removeAll()
        resetHoverState()
    }

    deinit {
        stop()
    }

    private func start() {
        refreshScreens()
        observeWorkspace()

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollPointerLocation()
        }
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        showPreview()
    }

    private func refreshScreens() {
        for bar in bars.values {
            bar.panel.orderOut(nil)
        }
        bars.removeAll()
        resetHoverState()

        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen), displayID != targetDisplayID else {
                continue
            }
            let panelAndStack = makePanel()
            bars[displayID] = Bar(
                displayID: displayID,
                screen: screen,
                panel: panelAndStack.panel,
                effect: panelAndStack.effect,
                stack: panelAndStack.stack
            )
        }

        refreshApplications()
    }

    private func observeWorkspace() {
        guard workspaceObservers.isEmpty else {
            return
        }

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]

        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshApplications()
            }
        }
    }

    private func makePanel() -> (panel: NSPanel, effect: DockBackdropView, stack: NSStackView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: initialPanelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false

        let effect = DockBackdropView(frame: panel.contentView?.bounds ?? .zero)
        effect.autoresizingMask = [.width, .height]
        effect.material = NSVisualEffectView.Material(rawValue: 8) ?? .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.alphaValue = 1
        effect.dockCornerRadius = 18
        effect.tintColor = NSColor.white.withAlphaComponent(backdropTintAlpha)
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.white
            .withAlphaComponent(backdropBorderAlpha)
            .cgColor
        panel.contentView = effect

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = iconSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: panelHorizontalPadding),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -panelHorizontalPadding),
            stack.centerYAnchor.constraint(equalTo: effect.centerYAnchor)
        ])

        return (panel, effect, stack)
    }

    private func refreshApplications() {
        guard isEnabled else {
            return
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications
            .filter {
                $0.processIdentifier != ownPID &&
                    !$0.isTerminated &&
                    $0.activationPolicy == .regular
            }
            .sorted {
                let lhs = $0.localizedName ?? ""
                let rhs = $1.localizedName ?? ""
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }

        for bar in bars.values {
            rebuild(bar: bar, applications: applications)
        }
    }

    private func rebuild(bar: Bar, applications: [NSRunningApplication]) {
        for view in bar.stack.arrangedSubviews {
            bar.stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let maximumPanelWidth = max(120, bar.screen.frame.width - 40)
        let minimumSlotSize = minimumIconSize + iconSlotPadding
        let maximumCount = max(
            1,
            Int(
                (maximumPanelWidth - panelHorizontalPadding * 2 + iconSpacing)
                    / (minimumSlotSize + iconSpacing)
            )
        )

        var visibleApplications = Array(applications.prefix(maximumCount))
        if let activeApplication = applications.first(where: \.isActive),
           !visibleApplications.contains(where: { $0.processIdentifier == activeApplication.processIdentifier }),
           !visibleApplications.isEmpty {
            visibleApplications[visibleApplications.count - 1] = activeApplication
        }

        let count = visibleApplications.count
        let preferredIconSize = DockSystemController.currentTileSize()
        let spacingWidth = CGFloat(max(0, count - 1)) * iconSpacing
        let availableSlotSize = count > 0
            ? floor((maximumPanelWidth - panelHorizontalPadding * 2 - spacingWidth) / CGFloat(count))
            : preferredIconSize + iconSlotPadding
        let slotSize = min(preferredIconSize + iconSlotPadding, availableSlotSize)
        let iconSize = max(minimumIconSize, slotSize - iconSlotPadding)

        for application in visibleApplications {
            bar.stack.addArrangedSubview(
                makeApplicationView(application, iconSize: iconSize, slotSize: slotSize)
            )
        }

        let width = panelHorizontalPadding * 2
            + CGFloat(count) * slotSize
            + spacingWidth
        // The icon itself is centered vertically. The running indicator sits
        // below it without shifting the icon row upward.
        let height = iconSize + panelVerticalPadding * 2
        bar.effect.dockCornerRadius = min(21, max(18, height * 0.27))
        position(panel: bar.panel, on: bar.screen, width: max(64, width), height: height)

        if count == 0, visibleDisplayID == bar.displayID {
            hideVisibleBar()
        }
    }

    private func makeApplicationView(
        _ application: NSRunningApplication,
        iconSize: CGFloat,
        slotSize: CGFloat
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // NSButtonCell adds substantial image insets even when borderless,
        // which made a 46–56 pt slot render as a roughly 32 pt icon. Draw the
        // icon at its real tile size and put a transparent button on top.
        let imageView = NSImageView()
        imageView.image = application.icon ?? fallbackApplicationIcon()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.alphaValue = application.isHidden ? 0.58 : 1.0
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        let button = NSButton(title: "", target: self, action: #selector(activateApplication(_:)))
        button.tag = Int(application.processIdentifier)
        button.toolTip = application.localizedName
        button.setAccessibilityLabel(application.localizedName)
        button.isBordered = false
        button.isTransparent = true
        button.refusesFirstResponder = true
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        let indicator = NSView()
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = NSColor.secondaryLabelColor.cgColor
        indicator.layer?.cornerRadius = 2
        indicator.isHidden = !application.isActive
        indicator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(indicator)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: slotSize),
            container.heightAnchor.constraint(equalToConstant: iconSize),
            imageView.widthAnchor.constraint(equalToConstant: iconSize),
            imageView.heightAnchor.constraint(equalToConstant: iconSize),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            indicator.widthAnchor.constraint(equalToConstant: indicatorSize),
            indicator.heightAnchor.constraint(equalToConstant: indicatorSize),
            indicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -indicatorGap)
        ])

        return container
    }

    private func fallbackApplicationIcon() -> NSImage {
        NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 32, height: 32))
    }

    private func position(panel: NSPanel, on screen: NSScreen, width: CGFloat, height: CGFloat) {
        let x = screen.frame.midX - width / 2
        let y = screen.frame.minY + panelBottomInset
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    private func pollPointerLocation() {
        guard isEnabled, !bars.isEmpty else {
            return
        }

        let point = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime

        if let previewVisibleUntil, now < previewVisibleUntil {
            return
        }
        self.previewVisibleUntil = nil

        if let visibleDisplayID,
           let visibleBar = bars[visibleDisplayID],
           visibleBar.panel.frame.insetBy(dx: -10, dy: -10).contains(point) {
            outsideStartedAt = nil
            revealCandidateID = nil
            revealCandidateStartedAt = nil
            return
        }

        if let triggerBar = bars.values.first(where: { isInTriggerZone(point, screen: $0.screen) }) {
            outsideStartedAt = nil

            if visibleDisplayID == triggerBar.displayID {
                revealCandidateID = nil
                revealCandidateStartedAt = nil
                return
            }

            if revealCandidateID != triggerBar.displayID {
                revealCandidateID = triggerBar.displayID
                revealCandidateStartedAt = now
                return
            }

            if let revealCandidateStartedAt, now - revealCandidateStartedAt >= revealDelay {
                showBar(on: triggerBar.displayID)
                self.revealCandidateID = nil
                self.revealCandidateStartedAt = nil
            }
            return
        }

        revealCandidateID = nil
        revealCandidateStartedAt = nil

        guard visibleDisplayID != nil else {
            outsideStartedAt = nil
            return
        }

        if outsideStartedAt == nil {
            outsideStartedAt = now
        } else if let outsideStartedAt, now - outsideStartedAt >= hideDelay {
            hideVisibleBar()
        }
    }

    private func isInTriggerZone(_ point: CGPoint, screen: NSScreen) -> Bool {
        let frame = screen.frame
        guard point.x >= frame.minX + horizontalTriggerInset,
              point.x < frame.maxX - horizontalTriggerInset,
              point.y >= frame.minY + triggerMinY,
              point.y <= frame.minY + triggerMaxY else {
            return false
        }
        return true
    }

    private func showBar(on displayID: CGDirectDisplayID) {
        guard let bar = bars[displayID], !bar.stack.arrangedSubviews.isEmpty else {
            return
        }

        if let visibleDisplayID, visibleDisplayID != displayID {
            bars[visibleDisplayID]?.panel.orderOut(nil)
        }

        visibleDisplayID = displayID
        outsideStartedAt = nil
        bar.panel.orderFrontRegardless()
    }

    private func hideVisibleBar() {
        if let visibleDisplayID {
            bars[visibleDisplayID]?.panel.orderOut(nil)
        }
        visibleDisplayID = nil
        outsideStartedAt = nil
    }

    private func showPreview() {
        guard let displayID = bars.keys.sorted().first else {
            return
        }
        showBar(on: displayID)
        previewVisibleUntil = ProcessInfo.processInfo.systemUptime + 2.0
    }

    private func resetHoverState() {
        revealCandidateID = nil
        revealCandidateStartedAt = nil
        visibleDisplayID = nil
        outsideStartedAt = nil
        previewVisibleUntil = nil
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    @objc private func activateApplication(_ sender: NSButton) {
        let processIdentifier = pid_t(sender.tag)
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == processIdentifier
        }) else {
            refreshApplications()
            return
        }

        application.unhide()
        application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        hideVisibleBar()
    }
}
