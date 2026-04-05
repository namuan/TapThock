import AppKit
import SwiftUI

final class OnboardingWindow: NSWindow {
    init(appModel: AppModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = "Welcome to TapThock"
        isReleasedWhenClosed = false
        center()
        contentViewController = NSHostingController(rootView: OnboardingView(appModel: appModel))
    }
}
