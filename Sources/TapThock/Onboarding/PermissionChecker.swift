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
    var hasInputMonitoringAccess = InputMonitoring.hasAccess {
        didSet {
            guard hasInputMonitoringAccess != oldValue else { return }
            AppLog.info("PermissionChecker", "Input Monitoring permission changed", metadata: [
                "hasAccess": "\(hasInputMonitoringAccess)",
            ])
        }
    }

    var isMissingRequiredPermissions: Bool {
        !isTrusted || !hasInputMonitoringAccess
    }

    func startMonitoring() {
        isTrusted = Accessibility.isTrusted
        hasInputMonitoringAccess = InputMonitoring.hasAccess
        AppLog.info("PermissionChecker", "Starting permission monitoring", metadata: [
            "hasInputMonitoringAccess": "\(hasInputMonitoringAccess)",
            "isTrusted": "\(isTrusted)",
        ])
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isTrusted = Accessibility.isTrusted
                self?.hasInputMonitoringAccess = InputMonitoring.hasAccess
            }
        }
    }

    func requestAccessibilityAccess() {
        AppLog.info("PermissionChecker", "Requesting accessibility permission")
        Accessibility.requestAccess()
        isTrusted = Accessibility.isTrusted
        AppLog.info("PermissionChecker", "Accessibility permission request finished", metadata: [
            "isTrusted": "\(isTrusted)",
        ])
    }

    func requestInputMonitoringAccess() {
        AppLog.info("PermissionChecker", "Requesting input monitoring permission")
        InputMonitoring.requestAccess()
        hasInputMonitoringAccess = InputMonitoring.hasAccess
        AppLog.info("PermissionChecker", "Input monitoring permission request finished", metadata: [
            "hasAccess": "\(hasInputMonitoringAccess)",
        ])
    }

    func requestAccess() {
        requestAccessibilityAccess()
    }
}
