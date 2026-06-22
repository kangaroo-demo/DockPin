import AppKit
import CoreGraphics

final class DisplayManager {
    func displays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }

            let id = CGDirectDisplayID(number.uint32Value)
            return DisplayInfo(
                id: id,
                uuid: Self.uuidString(for: id),
                name: screen.localizedName,
                bounds: CGDisplayBounds(id),
                isMain: id == CGMainDisplayID()
            )
        }
        .sorted { lhs, rhs in
            if lhs.bounds.minY == rhs.bounds.minY {
                return lhs.bounds.minX < rhs.bounds.minX
            }
            return lhs.bounds.minY < rhs.bounds.minY
        }
    }

    func selectedDisplay(uuid: String?, name: String?) -> DisplayInfo? {
        let allDisplays = displays()
        if let selected = allDisplays.first(where: { DisplayMatcher.matches(display: $0, uuid: uuid, name: name) }) {
            return selected
        }
        return allDisplays.first(where: \.isMain) ?? allDisplays.first
    }

    private static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }
        let uuid = unmanagedUUID.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }
}
