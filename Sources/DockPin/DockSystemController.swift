import AppKit
import CoreGraphics
import Foundation

enum DockSystemController {
    private static let dockDomain = "com.apple.dock" as CFString
    private static let orientationKey = "orientation" as CFString
    private static let tileSizeKey = "tilesize" as CFString

    static func currentEdge() -> DockEdge {
        guard
            let value = CFPreferencesCopyAppValue(orientationKey, dockDomain) as? String,
            let edge = DockEdge(rawValue: value)
        else {
            return .bottom
        }
        return edge
    }

    static func setDockEdge(_ edge: DockEdge) {
        guard currentEdge() != edge else {
            return
        }

        CFPreferencesSetAppValue(orientationKey, edge.rawValue as CFString, dockDomain)
        CFPreferencesAppSynchronize(dockDomain)
        restartDock()
    }

    static func currentTileSize() -> CGFloat {
        guard let value = CFPreferencesCopyAppValue(tileSizeKey, dockDomain) as? NSNumber else {
            return 56
        }
        return min(max(CGFloat(value.doubleValue), 32), 80)
    }

    static func owningDisplayID(for edge: DockEdge) -> CGDirectDisplayID? {
        let insetThreshold: CGFloat = 4

        for screen in NSScreen.screens {
            guard
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else {
                continue
            }

            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let dockInset: CGFloat

            switch edge {
            case .bottom:
                dockInset = visibleFrame.minY - frame.minY
            case .left:
                dockInset = visibleFrame.minX - frame.minX
            case .right:
                dockInset = frame.maxX - visibleFrame.maxX
            }

            if dockInset > insetThreshold {
                return CGDirectDisplayID(number.uint32Value)
            }
        }

        return nil
    }

    private static func restartDock() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
    }
}
