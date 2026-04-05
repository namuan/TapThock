# TapThock

TapThock is a SwiftPM-only macOS menu bar app that adds mechanical keyboard, mouse-click, and scroll-wheel sounds to global input with a native onboarding flow and generated built-in sound packs.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools or Xcode with a working Swift 6 toolchain

## Development

```bash
xcrun swift build
xcrun swift run TapThock
```

## Packaging

```bash
./install.command
```

That script creates the app bundle from a release build and installs `TapThock.app` into `~/Applications` without requiring an Xcode project.
