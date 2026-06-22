import CoreGraphics
import Foundation

final class DockEdgeController {
    private let displayManager: DisplayManager
    private let preferences: PreferencesStore

    private var anchor: DisplayInfo?
    private var gateStartedAt: Date?
    private var bypassUntil = Date.distantPast
    private var lastRefresh = Date.distantPast

    private let edgeBand: CGFloat = 72
    private let clampInset: CGFloat = 2
    private let refreshInterval: TimeInterval = 1.0

    init(displayManager: DisplayManager, preferences: PreferencesStore) {
        self.displayManager = displayManager
        self.preferences = preferences
        refreshAnchor(force: true)
    }

    var currentAnchor: DisplayInfo? {
        anchor
    }

    var allDisplays: [DisplayInfo] {
        displayManager.displays()
    }

    func refreshAnchor(force: Bool = false) {
        if !force && Date().timeIntervalSince(lastRefresh) < refreshInterval {
            return
        }

        lastRefresh = Date()
        anchor = displayManager.selectedDisplay(
            uuid: preferences.selectedDisplayUUID,
            name: preferences.selectedDisplayName
        )
    }

    func resetGate() {
        gateStartedAt = nil
        bypassUntil = .distantPast
    }

    func nudgePinnedDock(restoreCursor: Bool = true) {
        refreshAnchor(force: true)
        guard let anchor else {
            return
        }
        nudgeDock(to: anchor, edge: preferences.dockEdge, restoreCursor: restoreCursor)
    }

    func nudgeSystemDefaultDock(restoreCursor: Bool = true) {
        let edge = DockSystemController.currentEdge()
        guard let display = defaultDisplay(for: edge) else {
            return
        }
        nudgeDock(to: display, edge: edge, restoreCursor: restoreCursor)
    }

    func handle(event: CGEvent) -> CGEvent {
        guard preferences.isProtectionEnabled else {
            gateStartedAt = nil
            return event
        }

        refreshAnchor()

        guard let anchor else {
            return event
        }

        let now = Date()
        let location = event.location
        let edge = preferences.dockEdge

        guard isInsideProtectedZone(point: location, bounds: anchor.bounds, edge: edge) else {
            gateStartedAt = nil
            return event
        }

        if event.flags.contains(.maskAlternate) || now < bypassUntil {
            gateStartedAt = nil
            return event
        }

        if gateStartedAt == nil {
            gateStartedAt = now
        } else if let gateStartedAt, now.timeIntervalSince(gateStartedAt) >= preferences.gateHoldDuration {
            self.gateStartedAt = nil
            bypassUntil = now.addingTimeInterval(preferences.bypassDuration)
            return event
        }

        let clamped = clampedPoint(from: location, bounds: anchor.bounds, edge: edge)
        if hypot(location.x - clamped.x, location.y - clamped.y) < 0.5 {
            return event
        }

        event.location = clamped
        CGWarpMouseCursorPosition(clamped)
        return event
    }

    private func isInsideProtectedZone(point: CGPoint, bounds: CGRect, edge: DockEdge) -> Bool {
        let fraction = CGFloat(preferences.protectedWidthFraction)

        switch edge {
        case .bottom:
            let horizontalGap = bounds.width * (1 - fraction) / 2
            guard point.x >= bounds.minX + horizontalGap && point.x <= bounds.maxX - horizontalGap else {
                return false
            }
            return point.y >= bounds.maxY - 1 && point.y <= bounds.maxY + edgeBand

        case .left:
            let verticalGap = bounds.height * (1 - fraction) / 2
            guard point.y >= bounds.minY + verticalGap && point.y <= bounds.maxY - verticalGap else {
                return false
            }
            return point.x >= bounds.minX - edgeBand && point.x <= bounds.minX + 1

        case .right:
            let verticalGap = bounds.height * (1 - fraction) / 2
            guard point.y >= bounds.minY + verticalGap && point.y <= bounds.maxY - verticalGap else {
                return false
            }
            return point.x >= bounds.maxX - 1 && point.x <= bounds.maxX + edgeBand
        }
    }

    private func clampedPoint(from point: CGPoint, bounds: CGRect, edge: DockEdge) -> CGPoint {
        switch edge {
        case .bottom:
            return CGPoint(x: point.x, y: bounds.maxY - clampInset)
        case .left:
            return CGPoint(x: bounds.minX + clampInset, y: point.y)
        case .right:
            return CGPoint(x: bounds.maxX - clampInset, y: point.y)
        }
    }

    private func defaultDisplay(for edge: DockEdge) -> DisplayInfo? {
        let displays = displayManager.displays()
        switch edge {
        case .bottom:
            return displays.max { $0.bounds.maxY < $1.bounds.maxY }
        case .left:
            return displays.min { $0.bounds.minX < $1.bounds.minX }
        case .right:
            return displays.max { $0.bounds.maxX < $1.bounds.maxX }
        }
    }

    private func nudgeDock(to display: DisplayInfo, edge: DockEdge, restoreCursor: Bool) {
        let originalLocation = CGEvent(source: nil)?.location
        let first = pointInsideEdge(bounds: display.bounds, edge: edge)
        let second = pointBeyondEdge(bounds: display.bounds, edge: edge)

        postMouseMove(to: first)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.postMouseMove(to: second)
            guard restoreCursor, let originalLocation else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                self?.postMouseMove(to: originalLocation)
            }
        }
    }

    private func pointInsideEdge(bounds: CGRect, edge: DockEdge) -> CGPoint {
        switch edge {
        case .bottom:
            return CGPoint(x: bounds.midX, y: bounds.maxY - 8)
        case .left:
            return CGPoint(x: bounds.minX + 8, y: bounds.midY)
        case .right:
            return CGPoint(x: bounds.maxX - 8, y: bounds.midY)
        }
    }

    private func pointBeyondEdge(bounds: CGRect, edge: DockEdge) -> CGPoint {
        switch edge {
        case .bottom:
            return CGPoint(x: bounds.midX, y: bounds.maxY + 48)
        case .left:
            return CGPoint(x: bounds.minX - 48, y: bounds.midY)
        case .right:
            return CGPoint(x: bounds.maxX + 48, y: bounds.midY)
        }
    }

    private func postMouseMove(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
    }
}
