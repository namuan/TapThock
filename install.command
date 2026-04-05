#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

APP_NAME="TapThock"
BUNDLE_ID="com.tapthock.app"
CONFIGURATION="release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP_DIR="$INSTALL_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_ARGS=(-c "$CONFIGURATION")
SHOULD_OPEN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --open)
      SHOULD_OPEN=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--open]" >&2
      exit 1
      ;;
  esac
done

rm -rf "$ROOT_DIR/.build" "$APP_DIR"
mkdir -p "$DIST_DIR"
xcrun swift build "${BUILD_ARGS[@]}"

BIN_DIR="$(xcrun swift build "${BUILD_ARGS[@]}" --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -name "${APP_NAME}_*.bundle" | head -n 1)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

if [[ -n "${RESOURCE_BUNDLE:-}" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>TapThock</string>
  <key>CFBundleExecutable</key>
  <string>TapThock</string>
  <key>CFBundleIdentifier</key>
  <string>com.tapthock.app</string>
  <key>CFBundleName</key>
  <string>TapThock</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAccessibilityUsageDescription</key>
  <string>TapThock uses Accessibility access to play sounds while you type anywhere on your Mac.</string>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

mkdir -p "$INSTALL_DIR"
tccutil reset Accessibility "$BUNDLE_ID"
rm -rf "$INSTALLED_APP_DIR"
mv "$APP_DIR" "$INSTALLED_APP_DIR"

echo "Installed $INSTALLED_APP_DIR"

if [[ "$SHOULD_OPEN" == true ]]; then
  open "$INSTALLED_APP_DIR"
fi
