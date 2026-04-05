import AppKit
import SwiftUI

final class OnboardingWindow: NSWindow, NSWindowDelegate {
    private let onClose: () -> Void

    init(appModel: AppModel, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = "Welcome to TapThock"
        isReleasedWhenClosed = false
        delegate = self
        collectionBehavior = [.moveToActiveSpace]
        center()
        contentViewController = NSHostingController(rootView: OnboardingView(appModel: appModel))
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
