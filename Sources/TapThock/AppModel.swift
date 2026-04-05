import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private enum Keys {
        static let selectedPackID = "selectedPackID"
        static let masterVolume = "masterVolume"
        static let keyboardVolume = "keyboardVolume"
        static let mouseVolume = "mouseVolume"
        static let scrollVolume = "scrollVolume"
        static let keyboardEnabled = "keyboardEnabled"
        static let mouseEnabled = "mouseEnabled"
        static let scrollEnabled = "scrollEnabled"
        static let isEnabled = "isEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let showDockIcon = "showDockIcon"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let onboardingLastStep = "onboardingLastStep"
    }

    let permissionChecker = PermissionChecker()
    let soundManager = SoundManager()
    let statusBarManager = StatusBarManager()
    @ObservationIgnored private var eventMonitor: EventMonitor!

    private let defaults: UserDefaults
    @ObservationIgnored private var onboardingWindow: OnboardingWindow?
    private var didFinishLaunching = false

    var availablePacks: [SoundPack] = []
    var statusMessage: String?

    var selectedPackID: String {
        didSet {
            defaults.set(selectedPackID, forKey: Keys.selectedPackID)
            soundManager.selectPack(id: selectedPackID)
        }
    }

    var masterVolume: Double {
        didSet {
            defaults.set(masterVolume, forKey: Keys.masterVolume)
        }
    }

    var keyboardVolume: Double {
        didSet {
            defaults.set(keyboardVolume, forKey: Keys.keyboardVolume)
        }
    }

    var mouseVolume: Double {
        didSet {
            defaults.set(mouseVolume, forKey: Keys.mouseVolume)
        }
    }

    var scrollVolume: Double {
        didSet {
            defaults.set(scrollVolume, forKey: Keys.scrollVolume)
        }
    }

    var keyboardEnabled: Bool {
        didSet {
            defaults.set(keyboardEnabled, forKey: Keys.keyboardEnabled)
        }
    }

    var mouseEnabled: Bool {
        didSet {
            defaults.set(mouseEnabled, forKey: Keys.mouseEnabled)
        }
    }

    var scrollEnabled: Bool {
        didSet {
            defaults.set(scrollEnabled, forKey: Keys.scrollEnabled)
        }
    }

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            refreshMonitoring()
        }
    }

    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            do {
                try LaunchAtLogin.setEnabled(launchAtLogin)
                statusMessage = nil
            } catch {
                statusMessage = error.localizedDescription
                defaults.set(LaunchAtLogin.isEnabled, forKey: Keys.launchAtLogin)
            }
        }
    }

    var showDockIcon: Bool {
        didSet {
            defaults.set(showDockIcon, forKey: Keys.showDockIcon)
            statusBarManager.applyDockVisibility(showDockIcon)
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    var onboardingLastStep: Int {
        didSet {
            defaults.set(onboardingLastStep, forKey: Keys.onboardingLastStep)
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedPackID = defaults.string(forKey: Keys.selectedPackID) ?? ""
        masterVolume = defaults.object(forKey: Keys.masterVolume) as? Double ?? 0.85
        keyboardVolume = defaults.object(forKey: Keys.keyboardVolume) as? Double ?? 1.0
        mouseVolume = defaults.object(forKey: Keys.mouseVolume) as? Double ?? 0.9
        scrollVolume = defaults.object(forKey: Keys.scrollVolume) as? Double ?? 0.55
        keyboardEnabled = defaults.object(forKey: Keys.keyboardEnabled) as? Bool ?? true
        mouseEnabled = defaults.object(forKey: Keys.mouseEnabled) as? Bool ?? true
        scrollEnabled = defaults.object(forKey: Keys.scrollEnabled) as? Bool ?? true
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        showDockIcon = defaults.object(forKey: Keys.showDockIcon) as? Bool ?? false
        hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false
        onboardingLastStep = defaults.object(forKey: Keys.onboardingLastStep) as? Int ?? 0
        eventMonitor = EventMonitor(appModel: self)
        permissionChecker.onChange = { [weak self] in
            self?.handlePermissionChange()
        }

        AppLog.info("AppModel", "Initialized persisted state", metadata: [
            "hasCompletedOnboarding": "\(hasCompletedOnboarding)",
            "isEnabled": "\(isEnabled)",
            "keyboardEnabled": "\(keyboardEnabled)",
            "launchAtLogin": "\(launchAtLogin)",
            "masterVolume": String(format: "%.2f", masterVolume),
            "mouseEnabled": "\(mouseEnabled)",
            "verifiedAccessibilityAccess": "\(permissionChecker.hasVerifiedAccessibilityAccess)",
            "scrollEnabled": "\(scrollEnabled)",
            "selectedPackID": selectedPackID,
            "showDockIcon": "\(showDockIcon)",
        ])
    }

    func finishLaunching() {
        guard !didFinishLaunching else { return }
        didFinishLaunching = true

        AppLog.info("AppModel", "Finishing launch")

        statusBarManager.applyDockVisibility(showDockIcon)
        permissionChecker.startMonitoring()

        do {
            availablePacks = try SoundPack.defaultPacks()
            if selectedPackID.isEmpty || !availablePacks.contains(where: { $0.id == selectedPackID }) {
                selectedPackID = availablePacks.first?.id ?? ""
            }
            try soundManager.reload(with: availablePacks, selectedPackID: selectedPackID)
            statusMessage = nil
            AppLog.info("AppModel", "Loaded sound packs", metadata: [
                "count": "\(availablePacks.count)",
                "selectedPackID": selectedPackID,
            ])
        } catch {
            statusMessage = "Unable to load sound packs: \(error.localizedDescription)"
            AppLog.error("AppModel", "Failed to load sound packs", metadata: [
                "error": error.localizedDescription,
            ])
        }

        launchAtLogin = LaunchAtLogin.isEnabled
        refreshMonitoring()

        AppLog.info("AppModel", "Evaluated onboarding state", metadata: [
            "hasCompletedOnboarding": "\(hasCompletedOnboarding)",
            "hasVerifiedAccessibilityAccess": "\(permissionChecker.hasVerifiedAccessibilityAccess)",
            "missingRequiredPermissions": "\(permissionChecker.isMissingRequiredPermissions)",
            "shouldShowOnboardingOnLaunch": "\(shouldShowOnboardingOnLaunch)",
            "isTrusted": "\(permissionChecker.isTrusted)",
        ])

        if shouldShowOnboardingOnLaunch {
            DispatchQueue.main.async { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    func refreshMonitoring() {
        AppLog.info("AppModel", "Refreshing event monitoring", metadata: [
            "isEnabled": "\(isEnabled)",
        ])

        if isEnabled {
            eventMonitor.start()
        } else {
            eventMonitor.stop()
        }
    }

    func toggleEnabled() {
        isEnabled.toggle()
        AppLog.info("AppModel", "Toggled sound effects", metadata: [
            "isEnabled": "\(isEnabled)",
        ])
    }

    func selectPack(_ pack: SoundPack, preview: Bool = false) {
        selectedPackID = pack.id
        AppLog.info("AppModel", "Selected sound pack", metadata: [
            "packID": pack.id,
            "preview": "\(preview)",
        ])
        if preview {
            soundManager.preview(pack: pack, volume: effectiveKeyboardVolume)
        }
    }

    func previewCurrentPack() {
        AppLog.info("AppModel", "Previewing current pack", metadata: [
            "currentPackName": currentPackName,
            "selectedPackID": selectedPackID,
            "volume": String(format: "%.3f", effectiveKeyboardVolume),
        ])
        soundManager.preview(pack: soundManager.currentPack, volume: effectiveKeyboardVolume)
    }

    func preview(event: NSEvent) {
        AppLog.debug("AppModel", "Preview key received", metadata: [
            "characters": event.charactersIgnoringModifiers ?? "",
            "keyCode": "\(event.keyCode)",
            "volume": String(format: "%.3f", effectiveKeyboardVolume),
        ])
        soundManager.handlePreview(event: event, keyboardVolume: effectiveKeyboardVolume)
    }

    func playKeyboardSound(for event: NSEvent) {
        guard isEnabled, keyboardEnabled else {
            AppLog.debug("AppModel", "Skipped keyboard sound", metadata: [
                "isEnabled": "\(isEnabled)",
                "keyboardEnabled": "\(keyboardEnabled)",
                "keyCode": "\(event.keyCode)",
            ])
            return
        }

        soundManager.playKeyboard(event: event, volume: effectiveKeyboardVolume)
    }

    func playKeyboardSound(for event: CGEvent) {
        guard isEnabled, keyboardEnabled else {
            AppLog.debug("AppModel", "Skipped keyboard sound", metadata: [
                "isEnabled": "\(isEnabled)",
                "keyboardEnabled": "\(keyboardEnabled)",
            ])
            return
        }

        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        soundManager.playKeyboard(event: nsEvent, volume: effectiveKeyboardVolume)
    }

    func playMouseSound(button: MouseButton) {
        guard isEnabled, mouseEnabled else {
            AppLog.debug("AppModel", "Skipped mouse sound", metadata: [
                "button": "\(button.keyType.rawValue)",
                "isEnabled": "\(isEnabled)",
                "mouseEnabled": "\(mouseEnabled)",
            ])
            return
        }

        soundManager.playMouse(button: button, volume: effectiveMouseVolume)
    }

    func playScrollSound(deltaY: Double) {
        guard isEnabled, scrollEnabled else {
            AppLog.debug("AppModel", "Skipped scroll sound", metadata: [
                "deltaY": String(format: "%.3f", deltaY),
                "isEnabled": "\(isEnabled)",
                "scrollEnabled": "\(scrollEnabled)",
            ])
            return
        }

        soundManager.playScroll(deltaY: deltaY, volume: effectiveScrollVolume)
    }

    func playScrollSound(from event: NSEvent) {
        guard isEnabled, scrollEnabled else {
            AppLog.debug("AppModel", "Skipped scroll sound", metadata: [
                "deltaY": String(format: "%.3f", event.scrollingDeltaY),
                "isEnabled": "\(isEnabled)",
                "scrollEnabled": "\(scrollEnabled)",
            ])
            return
        }

        soundManager.playScroll(deltaY: event.scrollingDeltaY, volume: effectiveScrollVolume)
    }

    func showOnboarding() {
        AppLog.info("AppModel", "Showing onboarding window", metadata: [
            "hasVerifiedAccessibilityAccess": "\(permissionChecker.hasVerifiedAccessibilityAccess)",
            "initialStep": "\(initialOnboardingStep().rawValue)",
            "missingRequiredPermissions": "\(permissionChecker.isMissingRequiredPermissions)",
            "isTrusted": "\(permissionChecker.isTrusted)",
        ])

        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindow(appModel: self) { [weak self] in
                guard let self else { return }
                statusBarManager.endWindowPresentation(showDockIcon: showDockIcon)
            }
        }

        statusBarManager.beginWindowPresentation()
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingLastStep = OnboardingStep.finish.rawValue
        onboardingWindow?.orderOut(nil)
        statusBarManager.endWindowPresentation(showDockIcon: showDockIcon)
        AppLog.info("AppModel", "Completed onboarding")
    }

    func deferOnboarding() {
        onboardingWindow?.orderOut(nil)
        statusBarManager.endWindowPresentation(showDockIcon: showDockIcon)
        AppLog.info("AppModel", "Deferred onboarding")
    }

    func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
        statusBarManager.endWindowPresentation(showDockIcon: showDockIcon)
        AppLog.info("AppModel", "Closed onboarding window")
    }

    func setOnboardingStep(_ step: OnboardingStep) {
        onboardingLastStep = step.rawValue
        AppLog.info("AppModel", "Updated onboarding step", metadata: [
            "step": "\(step.rawValue)",
        ])
    }

    func initialOnboardingStep() -> OnboardingStep {
        let storedStep = OnboardingStep(rawValue: onboardingLastStep) ?? .welcome

        if !permissionChecker.isTrusted,
           storedStep.rawValue > OnboardingStep.accessibility.rawValue {
            return .accessibility
        }

        return storedStep
    }

    private var effectiveKeyboardVolume: Float {
        Float(masterVolume * keyboardVolume)
    }

    private var effectiveMouseVolume: Float {
        Float(masterVolume * mouseVolume)
    }

    private var effectiveScrollVolume: Float {
        Float(masterVolume * scrollVolume)
    }

    var currentPackName: String {
        soundManager.currentPack?.name ?? availablePacks.first?.name ?? "No Pack Selected"
    }

    private var shouldShowOnboardingOnLaunch: Bool {
        !hasCompletedOnboarding || permissionChecker.isMissingRequiredPermissions
    }

    private func handlePermissionChange() {
        guard didFinishLaunching else { return }

        AppLog.info("AppModel", "Handled permission change", metadata: [
            "hasVerifiedAccessibilityAccess": "\(permissionChecker.hasVerifiedAccessibilityAccess)",
            "isEnabled": "\(isEnabled)",
            "isTrusted": "\(permissionChecker.isTrusted)",
        ])

        guard isEnabled else { return }
        eventMonitor.stop()
        eventMonitor.start()
    }

    func noteObservedGlobalKeyboardEvent() {
        permissionChecker.noteObservedGlobalKeyboardEvent()
    }
}
