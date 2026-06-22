import CoreGraphics
import Foundation

final class DockEdgeController {
    private struct EdgeSegment {
        let start: CGFloat
        let end: CGFloat

        var length: CGFloat {
            max(0, end - start)
        }

        var midpoint: CGFloat {
            (start + end) / 2
        }

        func contains(_ value: CGFloat) -> Bool {
            value >= start && value <= end
        }

        func distance(to value: CGFloat) -> CGFloat {
            if contains(value) {
                return 0
            }
            return min(abs(value - start), abs(value - end))
        }

        func clampedValue(_ value: CGFloat, margin: CGFloat) -> CGFloat {
            guard length > margin * 2 else {
                return midpoint
            }
            return min(max(value, start + margin), end - margin)
        }
    }

    private let displayManager: DisplayManager
    private let preferences: PreferencesStore

    private var anchor: DisplayInfo?
    private var displaySnapshot: [DisplayInfo] = []
    private var gateStartedAt: Date?
    private var bypassUntil = Date.distantPast
    private var lastRefresh = Date.distantPast

    private let edgeBand: CGFloat = 72
    private let clampInset: CGFloat = 1
    private let activationMargin: CGFloat = 10
    private let adjacencyTolerance: CGFloat = 4
    private let minimumActivationSpan: CGFloat = 24
    private let refreshInterval: TimeInterval = 1.0
    private let dockActivationPulseCount = 14
    private let dockActivationPulseInterval: TimeInterval = 0.055

    init(displayManager: DisplayManager, preferences: PreferencesStore) {
        self.displayManager = displayManager
        self.preferences = preferences
        refreshAnchor(force: true)
    }

    var currentAnchor: DisplayInfo? {
        anchor
    }

    var allDisplays: [DisplayInfo] {
        displaySnapshot.isEmpty ? displayManager.displays() : displaySnapshot
    }

    func refreshAnchor(force: Bool = false) {
        if !force && Date().timeIntervalSince(lastRefresh) < refreshInterval {
            return
        }

        lastRefresh = Date()
        let displays = displayManager.displays()
        displaySnapshot = displays

        if let selected = displays.first(where: {
            DisplayMatcher.matches(
                display: $0,
                uuid: preferences.selectedDisplayUUID,
                name: preferences.selectedDisplayName
            )
        }) {
            anchor = selected
        } else {
            anchor = displays.first(where: \.isMain) ?? displays.first
        }
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
        refreshAnchor(force: true)
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

        if anchor == nil {
            refreshAnchor(force: true)
        }

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

        let clamped = clampedPoint(from: location, display: anchor, edge: edge)
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

    private func clampedPoint(from point: CGPoint, display: DisplayInfo, edge: DockEdge) -> CGPoint {
        let bounds = display.bounds
        switch edge {
        case .bottom:
            let segment = preferredSegment(
                for: exposedSegments(of: display, edge: edge),
                reference: point.x
            )
            let x = segment.clampedValue(point.x, margin: activationMargin)
            return CGPoint(x: x, y: bounds.maxY - clampInset)
        case .left:
            let segment = preferredSegment(
                for: exposedSegments(of: display, edge: edge),
                reference: point.y
            )
            let y = segment.clampedValue(point.y, margin: activationMargin)
            return CGPoint(x: bounds.minX + clampInset, y: y)
        case .right:
            let segment = preferredSegment(
                for: exposedSegments(of: display, edge: edge),
                reference: point.y
            )
            let y = segment.clampedValue(point.y, margin: activationMargin)
            return CGPoint(x: bounds.maxX - clampInset, y: y)
        }
    }

    private func defaultDisplay(for edge: DockEdge) -> DisplayInfo? {
        let displays = displaySnapshot.isEmpty ? displayManager.displays() : displaySnapshot
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
        gateStartedAt = nil
        bypassUntil = .distantPast

        for index in 0..<dockActivationPulseCount {
            let delay = TimeInterval(index) * dockActivationPulseInterval
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                let point = self.pointInsideEdge(display: display, edge: edge, offset: index, reference: originalLocation)
                self.postMouseMove(to: point)
            }
        }

        guard restoreCursor, let originalLocation else {
            return
        }

        let restoreDelay = TimeInterval(dockActivationPulseCount) * dockActivationPulseInterval + 0.18
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) { [weak self] in
            self?.postMouseMove(to: originalLocation)
        }
    }

    private func pointInsideEdge(display: DisplayInfo, edge: DockEdge, offset: Int = 0, reference: CGPoint?) -> CGPoint {
        let bounds = display.bounds
        let wobble = CGFloat((offset % 5) - 2) * 4

        switch edge {
        case .bottom:
            let referenceX = reference?.x ?? bounds.midX
            let segment = preferredSegment(
                for: exposedSegments(of: display, edge: edge),
                reference: referenceX
            )
            let x = segment.clampedValue(referenceX + wobble, margin: activationMargin)
            return CGPoint(x: x, y: bounds.maxY - clampInset)
        case .left:
            let referenceY = reference?.y ?? bounds.midY
            let segment = preferredSegment(
                for: exposedSegments(of: display, edge: edge),
                reference: referenceY
            )
            let y = segment.clampedValue(referenceY + wobble, margin: activationMargin)
            return CGPoint(x: bounds.minX + clampInset, y: y)
        case .right:
            let referenceY = reference?.y ?? bounds.midY
            let segment = preferredSegment(
                for: exposedSegments(of: display, edge: edge),
                reference: referenceY
            )
            let y = segment.clampedValue(referenceY + wobble, margin: activationMargin)
            return CGPoint(x: bounds.maxX - clampInset, y: y)
        }
    }

    private func exposedSegments(of display: DisplayInfo, edge: DockEdge) -> [EdgeSegment] {
        let bounds = display.bounds
        let otherBounds = (displaySnapshot.isEmpty ? displayManager.displays() : displaySnapshot)
            .filter { $0.id != display.id }
            .map(\.bounds)

        var segments: [EdgeSegment]
        switch edge {
        case .bottom:
            segments = [EdgeSegment(start: bounds.minX, end: bounds.maxX)]
            for other in otherBounds where abs(other.minY - bounds.maxY) <= adjacencyTolerance {
                segments = subtract(
                    EdgeSegment(start: max(bounds.minX, other.minX), end: min(bounds.maxX, other.maxX)),
                    from: segments
                )
            }
            return validSegments(segments, fallback: EdgeSegment(start: bounds.minX, end: bounds.maxX))

        case .left:
            segments = [EdgeSegment(start: bounds.minY, end: bounds.maxY)]
            for other in otherBounds where abs(other.maxX - bounds.minX) <= adjacencyTolerance {
                segments = subtract(
                    EdgeSegment(start: max(bounds.minY, other.minY), end: min(bounds.maxY, other.maxY)),
                    from: segments
                )
            }
            return validSegments(segments, fallback: EdgeSegment(start: bounds.minY, end: bounds.maxY))

        case .right:
            segments = [EdgeSegment(start: bounds.minY, end: bounds.maxY)]
            for other in otherBounds where abs(other.minX - bounds.maxX) <= adjacencyTolerance {
                segments = subtract(
                    EdgeSegment(start: max(bounds.minY, other.minY), end: min(bounds.maxY, other.maxY)),
                    from: segments
                )
            }
            return validSegments(segments, fallback: EdgeSegment(start: bounds.minY, end: bounds.maxY))
        }
    }

    private func subtract(_ cut: EdgeSegment, from segments: [EdgeSegment]) -> [EdgeSegment] {
        guard cut.length > 0 else {
            return segments
        }

        return segments.flatMap { segment -> [EdgeSegment] in
            if cut.end <= segment.start || cut.start >= segment.end {
                return [segment]
            }

            var remaining: [EdgeSegment] = []
            if cut.start > segment.start {
                remaining.append(EdgeSegment(start: segment.start, end: min(cut.start, segment.end)))
            }
            if cut.end < segment.end {
                remaining.append(EdgeSegment(start: max(cut.end, segment.start), end: segment.end))
            }
            return remaining
        }
    }

    private func validSegments(_ segments: [EdgeSegment], fallback: EdgeSegment) -> [EdgeSegment] {
        let valid = segments.filter { $0.length >= minimumActivationSpan }
        return valid.isEmpty ? [fallback] : valid
    }

    private func preferredSegment(for segments: [EdgeSegment], reference: CGFloat) -> EdgeSegment {
        segments.min { lhs, rhs in
            let lhsDistance = lhs.distance(to: reference)
            let rhsDistance = rhs.distance(to: reference)
            if abs(lhsDistance - rhsDistance) > 0.5 {
                return lhsDistance < rhsDistance
            }
            return lhs.length > rhs.length
        } ?? EdgeSegment(start: reference, end: reference)
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
