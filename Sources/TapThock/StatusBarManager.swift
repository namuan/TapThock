import AppKit

@MainActor
final class StatusBarManager {
    func applyDockVisibility(_ showDockIcon: Bool) {
        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }
}
