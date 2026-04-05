import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class EventMonitor {
    private weak var appModel: AppModel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastScrollEventAt: TimeInterval = 0

    var isRunning = false

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        AppLog.info("EventMonitor", "Starting global event monitoring with CGEventTap")

        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        )

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            AppLog.error("EventMonitor", "Failed to create event tap")
            isRunning = false
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        AppLog.info("EventMonitor", "Event tap installed successfully")
    }

    func stop() {
        guard isRunning else { return }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        AppLog.info("EventMonitor", "Stopped global event monitoring")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let characters = event.keyboardCharacter
            AppLog.debug("EventMonitor", "Captured key down", metadata: [
                "characters": characters,
                "keyCode": "\(keyCode)",
            ])
            DispatchQueue.main.async { [weak self] in
                self?.appModel?.noteObservedGlobalKeyboardEvent()
                self?.appModel?.playKeyboardSound(for: event)
            }

        case .leftMouseDown:
            AppLog.debug("EventMonitor", "Captured left mouse down")
            DispatchQueue.main.async { [weak self] in
                self?.appModel?.playMouseSound(button: .left)
            }

        case .rightMouseDown:
            AppLog.debug("EventMonitor", "Captured right mouse down")
            DispatchQueue.main.async { [weak self] in
                self?.appModel?.playMouseSound(button: .right)
            }

        case .otherMouseDown:
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            AppLog.debug("EventMonitor", "Captured other mouse down", metadata: [
                "buttonNumber": "\(buttonNumber)",
            ])
            DispatchQueue.main.async { [weak self] in
                let button: MouseButton
                switch buttonNumber {
                case 2: button = .middle
                case 3: button = .back
                case 4: button = .forward
                default: button = .middle
                }
                self?.appModel?.playMouseSound(button: button)
            }

        case .scrollWheel:
            let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            AppLog.debug("EventMonitor", "Captured scroll wheel event", metadata: [
                "deltaY": String(format: "%.3f", deltaY),
            ])
            DispatchQueue.main.async { [weak self] in
                self?.handleScroll(deltaY: deltaY)
            }

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }

    private func handleScroll(deltaY: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastScrollEventAt > 0.03 else {
            AppLog.debug("EventMonitor", "Dropped scroll event due to throttle")
            return
        }
        lastScrollEventAt = now
        appModel?.playScrollSound(deltaY: deltaY)
    }
}

private extension CGEvent {
    var keyboardCharacter: String {
        guard let nsEvent = NSEvent(cgEvent: self) else { return "" }
        return nsEvent.charactersIgnoringModifiers ?? ""
    }
}
