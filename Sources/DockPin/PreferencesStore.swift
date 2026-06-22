import Foundation

final class PreferencesStore {
    private enum Key {
        static let selectedDisplayUUID = "selectedDisplayUUID"
        static let selectedDisplayName = "selectedDisplayName"
        static let dockEdge = "dockEdge"
        static let protectedWidthFraction = "protectedWidthFraction"
        static let gateHoldDuration = "gateHoldDuration"
        static let bypassDuration = "bypassDuration"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults = UserDefaults.standard

    var selectedDisplayUUID: String? {
        get {
            defaults.string(forKey: Key.selectedDisplayUUID)
        }
        set {
            defaults.set(newValue, forKey: Key.selectedDisplayUUID)
        }
    }

    var selectedDisplayName: String? {
        get {
            defaults.string(forKey: Key.selectedDisplayName)
        }
        set {
            defaults.set(newValue, forKey: Key.selectedDisplayName)
        }
    }

    var dockEdge: DockEdge {
        get {
            DockEdge(rawValue: defaults.string(forKey: Key.dockEdge) ?? "") ?? .bottom
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.dockEdge)
        }
    }

    var protectedWidthFraction: Double {
        get {
            let value = defaults.double(forKey: Key.protectedWidthFraction)
            return value > 0 ? value : 0.40
        }
        set {
            defaults.set(min(max(newValue, 0.10), 1.0), forKey: Key.protectedWidthFraction)
        }
    }

    var gateHoldDuration: Double {
        get {
            let value = defaults.double(forKey: Key.gateHoldDuration)
            return value > 0 ? value : 0.20
        }
        set {
            defaults.set(min(max(newValue, 0.05), 2.0), forKey: Key.gateHoldDuration)
        }
    }

    var bypassDuration: Double {
        get {
            let value = defaults.double(forKey: Key.bypassDuration)
            return value > 0 ? value : 1.20
        }
        set {
            defaults.set(min(max(newValue, 0.20), 5.0), forKey: Key.bypassDuration)
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            defaults.object(forKey: Key.hasCompletedOnboarding) as? Bool ?? false
        }
        set {
            defaults.set(newValue, forKey: Key.hasCompletedOnboarding)
        }
    }

    func selectDisplay(_ display: DisplayInfo) {
        selectedDisplayUUID = display.uuid
        selectedDisplayName = display.name
    }
}
