import Foundation
import ServiceManagement

final class LaunchAtLoginController {
    enum Status {
        case enabled
        case disabled
        case requiresApproval
        case unsupported
    }

    var status: Status {
        guard #available(macOS 13.0, *) else {
            return .unsupported
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        default:
            return .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            return
        }

        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
