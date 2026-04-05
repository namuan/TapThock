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
    }

    func finishLaunching() {
        guard !didFinishLaunching else { return }
        didFinishLaunching = true

        statusBarManager.applyDockVisibility(showDockIcon)
        permissionChecker.startMonitoring()

        do {
            availablePacks = try SoundPack.defaultPacks()
            if selectedPackID.isEmpty || !availablePacks.contains(where: { $0.id == selectedPackID }) {
                selectedPackID = availablePacks.first?.id ?? ""
            }
            try soundManager.reload(with: availablePacks, selectedPackID: selectedPackID)
            statusMessage = nil
        } catch {
            statusMessage = "Unable to load sound packs: \(error.localizedDescription)"
        }

        launchAtLogin = LaunchAtLogin.isEnabled
        refreshMonitoring()

        if !hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func refreshMonitoring() {
        if isEnabled {
            eventMonitor.start()
        } else {
            eventMonitor.stop()
        }
    }

    func toggleEnabled() {
        isEnabled.toggle()
    }

    func selectPack(_ pack: SoundPack, preview: Bool = false) {
        selectedPackID = pack.id
        if preview {
            soundManager.preview(pack: pack, volume: effectiveKeyboardVolume)
        }
    }

    func previewCurrentPack() {
        soundManager.preview(pack: soundManager.currentPack, volume: effectiveKeyboardVolume)
    }

    func preview(event: NSEvent) {
        soundManager.handlePreview(event: event, keyboardVolume: effectiveKeyboardVolume)
    }

    func playKeyboardSound(for event: NSEvent) {
        guard isEnabled, keyboardEnabled else { return }
        soundManager.playKeyboard(event: event, volume: effectiveKeyboardVolume)
    }

    func playMouseSound(button: MouseButton) {
        guard isEnabled, mouseEnabled else { return }
        soundManager.playMouse(button: button, volume: effectiveMouseVolume)
    }

    func playScrollSound(deltaY: Double) {
        guard isEnabled, scrollEnabled else { return }
        soundManager.playScroll(deltaY: deltaY, volume: effectiveScrollVolume)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindow(appModel: self)
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingLastStep = OnboardingStep.finish.rawValue
        onboardingWindow?.orderOut(nil)
    }

    func deferOnboarding() {
        onboardingWindow?.orderOut(nil)
    }

    func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
    }

    func setOnboardingStep(_ step: OnboardingStep) {
        onboardingLastStep = step.rawValue
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
}
