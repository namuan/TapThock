import AppKit
import ApplicationServices

enum InputMonitoring {
    static var hasAccess: Bool {
        CGPreflightListenEventAccess()
    }

    static func requestAccess() {
        AppLog.info("InputMonitoring", "Requesting input monitoring permission")
        _ = CGRequestListenEventAccess()

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            AppLog.info("InputMonitoring", "Opening System Settings", metadata: [
                "url": url.absoluteString,
            ])
            NSWorkspace.shared.open(url)
        }
    }
}
