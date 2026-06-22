import AppKit
import CoreGraphics

struct DisplayInfo: Equatable {
    let id: CGDirectDisplayID
    let uuid: String?
    let name: String
    let bounds: CGRect
    let isMain: Bool

    var menuTitle: String {
        isMain ? L10n.t("display.main_format", name) : name
    }

    var stableDescription: String {
        "\(name) [\(Int(bounds.minX)), \(Int(bounds.minY)), \(Int(bounds.width))x\(Int(bounds.height))]"
    }
}

enum DockEdge: String, CaseIterable {
    case bottom
    case left
    case right

    var localizedTitle: String {
        switch self {
        case .bottom:
            return L10n.t("edge.bottom")
        case .left:
            return L10n.t("edge.left")
        case .right:
            return L10n.t("edge.right")
        }
    }
}

enum DisplayMatcher {
    static func matches(display: DisplayInfo, uuid: String?, name: String?) -> Bool {
        if let uuid, !uuid.isEmpty, display.uuid == uuid {
            return true
        }
        if let name, !name.isEmpty, display.name == name {
            return true
        }
        return false
    }
}
