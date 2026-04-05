import Foundation
import Observation

@MainActor
@Observable
final class PermissionChecker {
    private enum Keys {
        static let verifiedInputMonitoringAccess = "verifiedInputMonitoringAccess"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    private var timer: Timer?
    var onChange: (() -> Void)?
    var isTrusted = Accessibility.isTrusted {
        didSet {
            guard isTrusted != oldValue else { return }
            AppLog.info("PermissionChecker", "Accessibility permission changed", metadata: [
                "isTrusted": "\(isTrusted)",
            ])
            onChange?()
        }
    }
    var inputMonitoringAccessStatus = InputMonitoring.accessStatus {
        didSet {
            guard inputMonitoringAccessStatus != oldValue else { return }
            AppLog.info("PermissionChecker", "Input Monitoring access status changed", metadata: [
                "status": inputMonitoringAccessStatus.rawValue,
            ])
            onChange?()
        }
    }
    var hasInputMonitoringAccess = InputMonitoring.hasAccess {
        didSet {
            guard hasInputMonitoringAccess != oldValue else { return }
            AppLog.info("PermissionChecker", "Input Monitoring permission changed", metadata: [
                "hasAccess": "\(hasInputMonitoringAccess)",
            ])
            onChange?()
        }
    }
    var hasVerifiedInputMonitoringAccess = UserDefaults.standard.bool(forKey: Keys.verifiedInputMonitoringAccess) {
        didSet {
            guard hasVerifiedInputMonitoringAccess != oldValue else { return }
            defaults.set(hasVerifiedInputMonitoringAccess, forKey: Keys.verifiedInputMonitoringAccess)
            AppLog.info("PermissionChecker", "Input Monitoring verification changed", metadata: [
                "isVerified": "\(hasVerifiedInputMonitoringAccess)",
            ])
            onChange?()
        }
    }

    var isInputMonitoringReady: Bool {
        hasInputMonitoringAccess && hasVerifiedInputMonitoringAccess
    }

    var isMissingRequiredPermissions: Bool {
        !isTrusted || !isInputMonitoringReady
    }

    func refresh() {
        let diagnostics = InputMonitoring.diagnostics
        let updatedAccessibility = Accessibility.isTrusted
        let updatedInputMonitoringStatus = diagnostics.listenEventStatus
        let updatedInputMonitoring = updatedInputMonitoringStatus == .granted

        isTrusted = updatedAccessibility
        inputMonitoringAccessStatus = updatedInputMonitoringStatus
        hasInputMonitoringAccess = updatedInputMonitoring

        if !updatedInputMonitoring {
            hasVerifiedInputMonitoringAccess = false
        }

        AppLog.debug("PermissionChecker", "Refreshed permission state", metadata: [
            "hasInputMonitoringAccess": "\(hasInputMonitoringAccess)",
            "hasVerifiedInputMonitoringAccess": "\(hasVerifiedInputMonitoringAccess)",
            "isTrusted": "\(isTrusted)",
        ].merging(diagnostics.metadata) { _, newValue in newValue })
    }

    func startMonitoring() {
        refresh()
        AppLog.info("PermissionChecker", "Starting permission monitoring", metadata: [
            "hasInputMonitoringAccess": "\(hasInputMonitoringAccess)",
            "isTrusted": "\(isTrusted)",
        ])
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func requestAccessibilityAccess() {
        AppLog.info("PermissionChecker", "Requesting accessibility permission")
        Accessibility.requestAccess()
        refresh()
        AppLog.info("PermissionChecker", "Accessibility permission request finished", metadata: [
            "isTrusted": "\(isTrusted)",
        ])
    }

    func requestInputMonitoringAccess() {
        AppLog.info("PermissionChecker", "Requesting input monitoring permission")
        InputMonitoring.requestAccess()
        refresh()
        AppLog.info("PermissionChecker", "Input monitoring permission request finished", metadata: [
            "hasAccess": "\(hasInputMonitoringAccess)",
            "isVerified": "\(hasVerifiedInputMonitoringAccess)",
            "status": inputMonitoringAccessStatus.rawValue,
        ])
    }

    func noteObservedGlobalKeyboardEvent() {
        guard hasInputMonitoringAccess else { return }
        hasVerifiedInputMonitoringAccess = true
        AppLog.info("PermissionChecker", "Verified input monitoring via global keyboard capture")
    }

    func requestAccess() {
        requestAccessibilityAccess()
    }
}
