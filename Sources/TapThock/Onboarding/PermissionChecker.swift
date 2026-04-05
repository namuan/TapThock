import Foundation
import Observation

@MainActor
@Observable
final class PermissionChecker {
    private var timer: Timer?
    var isTrusted = Accessibility.isTrusted

    func startMonitoring() {
        isTrusted = Accessibility.isTrusted
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isTrusted = Accessibility.isTrusted
            }
        }
    }

    func requestAccess() {
        Accessibility.requestAccess()
        isTrusted = Accessibility.isTrusted
    }
}
