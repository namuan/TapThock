import Foundation
import Observation

@MainActor
@Observable
final class PermissionChecker {
    private enum Keys {
        static let verifiedAccessibilityAccess = "verifiedAccessibilityAccess"
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
    var hasVerifiedAccessibilityAccess = UserDefaults.standard.bool(forKey: Keys.verifiedAccessibilityAccess) {
        didSet {
            guard hasVerifiedAccessibilityAccess != oldValue else { return }
            defaults.set(hasVerifiedAccessibilityAccess, forKey: Keys.verifiedAccessibilityAccess)
            AppLog.info("PermissionChecker", "Accessibility verification changed", metadata: [
                "isVerified": "\(hasVerifiedAccessibilityAccess)",
            ])
            onChange?()
        }
    }

    var isReady: Bool {
        isTrusted && hasVerifiedAccessibilityAccess
    }

    var isMissingRequiredPermissions: Bool {
        !isReady
    }

    func refresh() {
        let updatedAccessibility = Accessibility.isTrusted
        isTrusted = updatedAccessibility

        if !updatedAccessibility {
            hasVerifiedAccessibilityAccess = false
        }

        AppLog.debug("PermissionChecker", "Refreshed permission state", metadata: [
            "hasVerifiedAccessibilityAccess": "\(hasVerifiedAccessibilityAccess)",
            "isTrusted": "\(isTrusted)",
        ])
    }

    func startMonitoring() {
        refresh()
        AppLog.info("PermissionChecker", "Starting permission monitoring", metadata: [
            "hasVerifiedAccessibilityAccess": "\(hasVerifiedAccessibilityAccess)",
            "isTrusted": "\(isTrusted)",
        ])
        timer?.invalidate()

        // Only start the polling timer if permissions are still missing.
        // The timer stops itself as soon as all permissions are confirmed.
        guard isMissingRequiredPermissions else {
            AppLog.info("PermissionChecker", "All permissions already granted; skipping timer")
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refresh()
                // Stop polling once all required permissions are in place.
                if !self.isMissingRequiredPermissions {
                    self.timer?.invalidate()
                    self.timer = nil
                    AppLog.info("PermissionChecker", "All permissions granted; stopped polling timer")
                }
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

    func noteObservedGlobalKeyboardEvent() {
        guard isTrusted else { return }
        hasVerifiedAccessibilityAccess = true
        AppLog.info("PermissionChecker", "Verified accessibility via global keyboard capture")
    }

    func requestAccess() {
        requestAccessibilityAccess()
    }
}
