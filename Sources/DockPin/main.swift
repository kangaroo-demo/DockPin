import AppKit

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
