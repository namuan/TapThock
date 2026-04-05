import AppKit
import ApplicationServices

enum Accessibility {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccess() {
        AppLog.info("Accessibility", "Opening accessibility permission prompt")
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            AppLog.info("Accessibility", "Opening System Settings", metadata: [
                "url": url.absoluteString,
            ])
            NSWorkspace.shared.open(url)
        }
    }
}
