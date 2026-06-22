import Foundation

enum DockSystemController {
    private static let dockDomain = "com.apple.dock" as CFString
    private static let orientationKey = "orientation" as CFString

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

    private static func restartDock() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
    }
}
