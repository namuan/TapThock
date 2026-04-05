import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        AppLog.info("LaunchAtLogin", "Updating launch-at-login setting", metadata: [
            "enabled": "\(enabled)",
            "status": "\(SMAppService.mainApp.status.rawValue)",
        ])

        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status == .enabled else { return }
            try service.unregister()
        }

        AppLog.info("LaunchAtLogin", "Updated launch-at-login setting", metadata: [
            "enabled": "\(enabled)",
            "status": "\(service.status.rawValue)",
        ])
    }
}
