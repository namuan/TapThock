import Foundation
import Observation

@MainActor
@Observable
final class PermissionChecker {
    private var timer: Timer?
    var isTrusted = Accessibility.isTrusted {
        didSet {
            guard isTrusted != oldValue else { return }
            AppLog.info("PermissionChecker", "Accessibility permission changed", metadata: [
                "isTrusted": "\(isTrusted)",
            ])
        }
    }

    var isMissingRequiredPermissions: Bool {
        !isTrusted
    }

    func startMonitoring() {
        isTrusted = Accessibility.isTrusted
        AppLog.info("PermissionChecker", "Starting permission monitoring", metadata: [
            "isTrusted": "\(isTrusted)",
        ])
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isTrusted = Accessibility.isTrusted
            }
        }
    }

    func requestAccess() {
        AppLog.info("PermissionChecker", "Requesting accessibility permission")
        Accessibility.requestAccess()
        isTrusted = Accessibility.isTrusted
        AppLog.info("PermissionChecker", "Accessibility permission request finished", metadata: [
            "isTrusted": "\(isTrusted)",
        ])
    }
}
