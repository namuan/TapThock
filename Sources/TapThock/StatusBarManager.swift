import AppKit

@MainActor
final class StatusBarManager {
    private var forcesRegularActivation = false

    func applyDockVisibility(_ showDockIcon: Bool) {
        guard !forcesRegularActivation else { return }

        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        AppLog.info("StatusBarManager", "Applied activation policy", metadata: [
            "policy": showDockIcon ? "regular" : "accessory",
        ])
    }

    func beginWindowPresentation() {
        forcesRegularActivation = true
        NSApp.setActivationPolicy(.regular)
        AppLog.info("StatusBarManager", "Began regular activation for window presentation")
    }

    func endWindowPresentation(showDockIcon: Bool) {
        forcesRegularActivation = false
        AppLog.info("StatusBarManager", "Ending temporary window presentation mode")
        applyDockVisibility(showDockIcon)
    }
}
