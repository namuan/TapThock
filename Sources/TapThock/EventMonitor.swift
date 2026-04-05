import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class EventMonitor {
    private weak var appModel: AppModel?
    private var monitors: [Any] = []
    private var lastScrollEventAt: TimeInterval = 0

    var isRunning = false

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.appModel?.playKeyboardSound(for: event)
            }
        }

        let leftMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.appModel?.playMouseSound(button: .left)
            }
        }

        let rightMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.appModel?.playMouseSound(button: .right)
            }
        }

        let otherMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                let button: MouseButton
                switch event.buttonNumber {
                case 2: button = .middle
                case 3: button = .back
                case 4: button = .forward
                default: button = .middle
                }
                self?.appModel?.playMouseSound(button: button)
            }
        }

        let scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleScroll(event)
            }
        }

        monitors = [keyboardMonitor, leftMouseMonitor, rightMouseMonitor, otherMouseMonitor, scrollMonitor].compactMap { $0 }
    }

    func stop() {
        guard isRunning else { return }
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        isRunning = false
    }

    private func handleScroll(_ event: NSEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastScrollEventAt > 0.03 else { return }
        lastScrollEventAt = now
        appModel?.playScrollSound(deltaY: event.scrollingDeltaY)
    }
}
