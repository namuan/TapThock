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
ICON_PNG="$ROOT_DIR/assets/tapthock-icon.png"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
ICON_ICNS="$ROOT_DIR/.build/AppIcon.icns"
BUILD_ARGS=(-c "$CONFIGURATION")
SHOULD_OPEN=false

reset_permission() {
  local service="$1"

  if tccutil reset "$service" "$BUNDLE_ID" >/dev/null 2>&1; then
    echo "Reset $service permissions for $BUNDLE_ID"
  else
    echo "Warning: unable to reset $service permissions for $BUNDLE_ID" >&2
  fi
}

create_icns_from_png() {
  if [ ! -f "$ICON_PNG" ]; then
    echo "No icon source found at $ICON_PNG. Skipping icon conversion."
    return 0
  fi

  if ! command -v sips >/dev/null 2>&1 || ! command -v iconutil >/dev/null 2>&1; then
    echo "Warning: sips/iconutil not available. Skipping icon conversion."
    return 0
  fi

  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  echo "Generating AppIcon.icns from icon.png..."
  sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
}


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

create_icns_from_png

BIN_DIR="$(xcrun swift build "${BUILD_ARGS[@]}" --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -name "${APP_NAME}_*.bundle" | head -n 1)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

if [[ -n "${RESOURCE_BUNDLE:-}" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

if [[ -f "$ICON_ICNS" ]]; then
  cp "$ICON_ICNS" "$RESOURCES_DIR/AppIcon.icns"
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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
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
reset_permission Accessibility
reset_permission ListenEvent
rm -rf "$INSTALLED_APP_DIR"
mv "$APP_DIR" "$INSTALLED_APP_DIR"

echo "Installed $INSTALLED_APP_DIR"

if [[ "$SHOULD_OPEN" == true ]]; then
  open "$INSTALLED_APP_DIR"
fi
