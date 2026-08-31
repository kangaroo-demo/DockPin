import AppKit
import ApplicationServices

if CommandLine.arguments.contains("--self-test-bar") {
    _ = NSApplication.shared
    let preferences = PreferencesStore()
    let targetDisplayID = DisplayManager()
        .selectedDisplay(
            uuid: preferences.selectedDisplayUUID,
            name: preferences.selectedDisplayName
        )?
        .id
    let controller = RunningAppBarController()
    controller.setEnabled(true, targetDisplayID: targetDisplayID)
    RunLoop.current.run(until: Date().addingTimeInterval(0.35))

    let passed = controller.isPresentingBarForDiagnostics
    print("barSelfTest=\(passed ? "passed" : "failed")")
    print("barState=\(controller.diagnosticSummary)")
    if let frame = controller.visiblePanelFrameForDiagnostics {
        print("barFrame=\(frame.origin.x),\(frame.origin.y),\(frame.width),\(frame.height)")
    }
    controller.stop()
    exit(passed ? 0 : 2)
}

if CommandLine.arguments.contains("--self-test-guard") {
    let preferences = PreferencesStore()
    let displayManager = DisplayManager()
    let edgeController = DockEdgeController(
        displayManager: displayManager,
        preferences: preferences
    )
    let originalLocation = CGEvent(source: nil)?.location
    let anchorID = edgeController.currentAnchor?.id

    guard
        AXIsProcessTrusted(),
        let testDisplay = edgeController.allDisplays.first(where: { $0.id != anchorID })
    else {
        print("guardSelfTest=unavailable")
        exit(1)
    }

    let requestedPoint: CGPoint
    switch preferences.dockEdge {
    case .bottom:
        requestedPoint = CGPoint(x: testDisplay.bounds.midX, y: testDisplay.bounds.maxY - 1)
    case .left:
        requestedPoint = CGPoint(x: testDisplay.bounds.minX + 1, y: testDisplay.bounds.midY)
    case .right:
        requestedPoint = CGPoint(x: testDisplay.bounds.maxX - 1, y: testDisplay.bounds.midY)
    }

    var handlerSawGuard = false
    var handlerClearedOutwardDelta = false
    var handlerAllowedInwardMove = false
    let inwardPoint: CGPoint
    switch preferences.dockEdge {
    case .bottom:
        inwardPoint = CGPoint(x: testDisplay.bounds.midX, y: testDisplay.bounds.maxY - 12)
    case .left:
        inwardPoint = CGPoint(x: testDisplay.bounds.minX + 12, y: testDisplay.bounds.midY)
    case .right:
        inwardPoint = CGPoint(x: testDisplay.bounds.maxX - 12, y: testDisplay.bounds.midY)
    }
    let eventTap = EventTapController { _, event in
        let before = event.location
        let handled = edgeController.handle(event: event)
        if hypot(before.x - requestedPoint.x, before.y - requestedPoint.y) < 3,
           hypot(handled.location.x - before.x, handled.location.y - before.y) >= 3 {
            handlerSawGuard = true
            let deltaX = handled.getIntegerValueField(.mouseEventDeltaX)
            let deltaY = handled.getIntegerValueField(.mouseEventDeltaY)
            handlerClearedOutwardDelta = deltaX == 0 && deltaY == 0
        }
        if hypot(before.x - inwardPoint.x, before.y - inwardPoint.y) < 3,
           hypot(handled.location.x - before.x, handled.location.y - before.y) < 1 {
            handlerAllowedInwardMove = true
        }
        return handled
    }
    eventTap.start()

    guard eventTap.isOperational else {
        print("guardSelfTest=eventTapUnavailable")
        exit(1)
    }

    let probeEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: requestedPoint,
        mouseButton: .left
    )
    switch preferences.dockEdge {
    case .bottom:
        probeEvent?.setIntegerValueField(.mouseEventDeltaY, value: 120)
    case .left:
        probeEvent?.setIntegerValueField(.mouseEventDeltaX, value: -120)
    case .right:
        probeEvent?.setIntegerValueField(.mouseEventDeltaX, value: 120)
    }
    probeEvent?.post(tap: .cghidEventTap)
    RunLoop.current.run(until: Date().addingTimeInterval(0.35))

    let observedPoint = CGEvent(source: nil)?.location ?? requestedPoint
    let keptAwayFromEdge: Bool
    switch preferences.dockEdge {
    case .bottom:
        keptAwayFromEdge = testDisplay.bounds.maxY - observedPoint.y >= 16
    case .left:
        keptAwayFromEdge = observedPoint.x - testDisplay.bounds.minX >= 16
    case .right:
        keptAwayFromEdge = testDisplay.bounds.maxX - observedPoint.x >= 16
    }


    let inwardEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: inwardPoint,
        mouseButton: .left
    )
    switch preferences.dockEdge {
    case .bottom:
        inwardEvent?.setIntegerValueField(.mouseEventDeltaY, value: -24)
    case .left:
        inwardEvent?.setIntegerValueField(.mouseEventDeltaX, value: 24)
    case .right:
        inwardEvent?.setIntegerValueField(.mouseEventDeltaX, value: -24)
    }
    inwardEvent?.post(tap: .cghidEventTap)
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

    // Always put the native Dock back on the selected display after the probe.
    edgeController.nudgePinnedDock(restoreCursor: false)
    RunLoop.current.run(until: Date().addingTimeInterval(1.15))
    if let originalLocation {
        CGWarpMouseCursorPosition(originalLocation)
    }
    eventTap.stop()

    let passed = handlerSawGuard
        && handlerClearedOutwardDelta
        && handlerAllowedInwardMove
        && keptAwayFromEdge
    print("guardSelfTest=\(passed ? "passed" : "failed")")
    print("testDisplay=\(testDisplay.name)")
    print("requested=\(requestedPoint.x),\(requestedPoint.y)")
    print("observed=\(observedPoint.x),\(observedPoint.y)")
    print("handlerSawGuard=\(handlerSawGuard)")
    print("handlerClearedOutwardDelta=\(handlerClearedOutwardDelta)")
    print("handlerAllowedInwardMove=\(handlerAllowedInwardMove)")
    exit(passed ? 0 : 2)
}

if CommandLine.arguments.contains("--diagnose") {
    let trusted = AXIsProcessTrusted()
    let eventTap = EventTapController { _, event in event }
    if trusted {
        eventTap.start()
    }

    print("accessibilityTrusted=\(trusted)")
    print("eventTapState=\(eventTap.state)")
    print("eventTapOperational=\(eventTap.isOperational)")
    exit(trusted && eventTap.isOperational ? 0 : 1)
}

if CommandLine.arguments.contains("--list-displays") {
    let displays = DisplayManager().displays()
    print("DockPin displays:")
    for display in displays {
        let main = display.isMain ? " main" : ""
        let uuid = display.uuid ?? "no-uuid"
        print("- \(display.name)\(main): \(uuid) \(display.stableDescription)")
    }
    exit(0)
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.run()
