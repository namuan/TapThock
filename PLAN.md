**RFC: TapThock – Mechanical Keyboard & Mouse Sound Simulator for macOS**  
**Tagline:** *Thocky mechanical typing + mouse clicks that feel alive*  

### 1. Abstract

TapThock is a **pure-Swift**, **SwiftPM-only**, zero-dependency macOS menu-bar application that injects realistic mechanical keyboard, typewriter, and mouse sounds (clicks + scroll wheel) into the global input stream with imperceptible latency (<1 ms).  

It delivers **subtle per-key sound variation** while adding native mouse support and 20+ sound packs. The entire codebase is built and distributed using only the Swift toolchain (`swift build`, `swift run`, `swift package`). No Xcode project, no `.xcodeproj`, no Xcode UI at any point in development, building, or packaging.

**Official Tagline:** *Thocky mechanical typing + mouse clicks that feel alive*

### 2. Motivation

- Existing solutions either require heavy frameworks, have noticeable latency, or lack mouse-scroll support.
- Users want **true mechanical feel** with natural variation per key (alphanumeric, space, enter, modifiers all sound different and never repeat identically).
- The app must be **native, lightweight (<15 MB installed), and instantly responsive**.
- **First-launch experience must be self-explanatory**: users should never be confused about why sounds don’t work immediately.
- Development must be possible on any machine with only `swift` installed (CI/CD friendly, contributor-friendly).

### 3. Goals & Non-Goals

**Goals**
- 0 % perceptible latency on 2020+ Macs (M1–M4).
- Subtle per-key + per-press variation (pitch, timbre, volume micro-changes).
- Full mouse click (left/right/others) + scroll-wheel support.
- 20+ built-in sound packs at launch (mechanical switches, typewriter, membrane, pure mouse, etc.).
- Pure Swift + SwiftPM (buildable with `swift build` only).
- Menu-bar only (optional dock icon via setting).
- Clear, guided onboarding for all permissions (Accessibility + Launch at Login).
- Elegant SwiftUI settings popover/window.
- UserDefaults-based persistence (no external files except sounds).
- Brand identity built around the satisfying “thock” sound that keyboard enthusiasts love.

**Non-Goals**
- Windows / Linux support (macOS-only).
- Custom sound recording inside the app.
- Per-app sound profiles (Phase 2).
- Any Objective-C outside of minimal AppKit bridging required by SwiftUI/AppKit.
- Xcode dependency of any kind.

### 4. Feature Set (MVP)

#### Core Features
- **Global Keyboard Sounds** with per-key mapping + random subtle variant + micro pitch shift (±0.02 rate).
- **Mouse Click Sounds** (left, right, middle, back, forward).
- **Mouse Scroll-Wheel Sounds** (velocity-sensitive single tick sound, intelligently throttled).
- **20+ Sound Packs** (each pack contains dedicated files for: alphanum variants, space, enter, backspace, tab, escape, modifiers, mouse-click, scroll-tick).
- **Zero-Latency Audio Engine** using a pre-warmed pool of `AVAudioPlayer` instances (`.caf` format only).
- **Menu Bar Extra** (`MenuBarExtra` on macOS 14+ with classic `NSStatusItem` fallback).
- **Settings UI** (SwiftUI popover or detached window):
  - Sound-pack grid with live preview.
  - Master volume + independent toggles (keyboard / mouse / scroll).
  - “Launch at login” toggle.
  - “Show in Dock” toggle.
  - “Test keyboard” area (type anywhere in the window to preview).
- **Accessibility auto-prompt** (NSAccessibility).
- **Instant on/off** from menu bar.

#### Onboarding Screen (First-Launch Experience)
- Appears **only once** (controlled by `UserDefaults` flag `hasCompletedOnboarding`).
- Full-screen, native SwiftUI window with clean dark/light mode support.
- Step-by-step guided flow:
  1. **Welcome** – Short animated intro with the tagline *Thocky mechanical typing + mouse clicks that feel alive*.
  2. **Accessibility Permission** – Explains exactly why it’s needed (“to hear sounds while you type anywhere on your Mac”).  
     - Large “Grant Accessibility Access” button that opens **System Settings → Privacy & Security → Accessibility**.  
     - Real-time status indicator (checks `AXIsProcessTrusted()`).  
     - “I’ve granted it” button becomes enabled only after permission is detected.  
     - Optional “Skip for now” with warning.
  3. **Launch at Login** (optional step) – Explains the toggle and offers to enable it immediately via `SMAppService`.
  4. **Finish** – Confirms everything is ready, shows a quick “Try typing” demo, then closes and activates the menu-bar app.
- Progress dots at the top (3–4 steps).
- “Remind me later” option that defers onboarding to next launch.
- Fully keyboard-navigable and VoiceOver accessible.

### 5. Project Structure (SwiftPM-only)

```bash
TapThock/
├── Package.swift
├── Sources/
│   └── TapThock/
│       ├── main.swift
│       ├── AppDelegate.swift                  # minimal AppKit glue
│       ├── TapThockApp.swift                   # @main SwiftUI App
│       ├── StatusBarManager.swift
│       ├── EventMonitor.swift
│       ├── SoundManager.swift
│       ├── AudioPlayerPool.swift
│       ├── SoundPack.swift
│       ├── SoundPack+DefaultPacks.swift
│       ├── Onboarding/
│       │   ├── OnboardingWindow.swift
│       │   ├── OnboardingView.swift
│       │   ├── OnboardingStepView.swift
│       │   └── PermissionChecker.swift
│       ├── Resources/
│       │   └── Sounds/                       # folder reference
│       └── Helpers/
│           ├── Accessibility.swift
│           └── LaunchAtLogin.swift
├── .gitignore
├── install.command          # pure CLI build + .app bundling script
└── README.md
```

**Package.swift** (exact content)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapThock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TapThock", targets: ["TapThock"])
    ],
    targets: [
        .executableTarget(
            name: "TapThock",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        )
    ]
)
```

### 6. Detailed Technical Architecture

#### 6.1 Event Capture (EventMonitor.swift)
Uses only `NSEvent.addGlobalMonitorForEvents(matching:)` for:
- `.keyDown`
- `.leftMouseDown`, `.rightMouseDown`, `.otherMouseDown`
- `.scrollWheel`

All monitors stored in a single array for clean start/stop.  
`EventMonitor` is `@Observable` and injected via environment.

#### 6.2 Zero-Latency Audio Engine (SoundManager + AudioPlayerPool)
- `AudioPlayerPool`: fixed-size pool (20 players) of pre-created `AVAudioPlayer` instances.
- All sounds preloaded at launch into memory.
- `play(file: URL, pitchShift: Double)` reuses idle player instantly and sets `rate` for pitch variation.
- File format: **.caf** (Apple Lossless or linear PCM 44.1 kHz/16-bit) → lowest possible latency on macOS.
- Variation logic (in `SoundPack`):
  - Alphanumeric keys: 3–5 variants per key group + random pitch ±2 %.
  - Space/Enter/Backspace/Tab/Esc: dedicated files with distinct timbre.
  - Modifiers: shorter, quieter variant.
  - Mouse clicks: left/right distinct files.
  - Scroll: single tick file, volume scaled by `scrollingDeltaY`.

#### 6.3 Sound Pack Model (SoundPack.swift)
```swift
struct SoundPack: Identifiable, Hashable {
    let id: String
    let name: String
    let folderURL: URL
    
    func soundURL(for keyType: KeyType, variant: Int = 0) -> URL
    func randomVariantURL(for keyType: KeyType) -> URL
    func pitchShift(for keyCode: UInt16) -> Double
}
```

Default packs defined in `SoundPack+DefaultPacks.swift` and loaded from `Bundle.module`.

#### 6.4 Onboarding Flow
- `OnboardingWindow.swift` – A plain `NSWindow` subclass hosting `OnboardingView` via `NSHostingController`.
- `OnboardingView.swift` – SwiftUI multi-step view using `@State` for current step and `@Observable` `PermissionChecker`.
- `PermissionChecker.swift` – Observable class that polls `AXIsProcessTrusted()` and provides real-time status + helper methods.
- Lifecycle: Checked in `TapThockApp.swift` init; shown exactly once.

#### 6.5 UI Layer (Pure SwiftUI)
- `@main struct TapThockApp: App`
- `MenuBarExtra` for macOS 14+ with `NSStatusItem` fallback in `AppDelegate`.
- Settings scene + onboarding window.

#### 6.6 Persistence
`@AppStorage` + `UserDefaults` only:
- Selected pack ID
- Volumes (keyboard, mouse, scroll)
- Launch at login
- Show in Dock
- Enabled state
- `hasCompletedOnboarding`
- `onboardingLastStep` (resumable)

### 7. Build & Distribution (No Xcode Required)

**Development workflow**
```bash
swift build                  # debug build
swift run                    # run directly (launches menu bar app)
```

**Release bundling** (`build.sh`)
Produces a fully notarizable **TapThock.app** bundle using only `swift`, `codesign`, `plutil`, and optional `create-dmg`.

### 8. Future Extensions (Post-MVP)
- Drag-and-drop custom .caf packs.
- Per-app mute/exclusion list.
- Sparkle auto-update (added as SPM target later).
- Keyboard shortcut global toggle.

### 9. Acceptance Criteria (Feature-only)
- App launches as **TapThock** and, on first run, shows the onboarding screen featuring the official tagline.
- Onboarding clearly explains and guides through Accessibility permission with real-time status.
- After granting Accessibility, sounds work immediately (no restart required).
- Launch-at-login step is optional and works via `SMAppService`.
- Onboarding is shown exactly once; subsequent launches go straight to menu bar.
- Entire app (including onboarding) builds and runs with only `swift build` / `swift run`.
- Total binary size < 8 MB (release stripped).
- GitHub repository name: `tapthock` (fully compatible).

This RFC defines the complete technical and feature foundation for **TapThock** as a pure-Swift, SPM-first macOS application.
