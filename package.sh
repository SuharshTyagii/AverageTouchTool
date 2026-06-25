#!/bin/bash
# Builds, signs, installs, and relaunches AverageTouchTool.app -- the one command
# to run after any code change.
#
# Why it signs with a real identity: macOS ties TCC permissions (Accessibility,
# Input Monitoring, Screen Recording) to the app's CODE SIGNATURE. An ad-hoc
# signature has no stable identity -- its hash changes every build -- so every
# rebuild looks like a brand-new app and macOS re-prompts for permissions.
# Signing with a stable identity (Apple Development / Developer ID) keeps the
# signature constant across rebuilds, so granted permissions persist.
#
# Bundle ID is intentionally kept as com.suharsh.bettertouch even though the app
# is now branded AverageTouchTool -- changing it would reset all permissions.
set -euo pipefail
cd "$(dirname "$0")"

APP="AverageTouchTool.app"
EXEC="BetterTouch"                       # SPM product name (binary inside the bundle)
BUNDLE_ID="com.suharsh.bettertouch"      # keep stable so permissions persist
DISPLAY_NAME="AverageTouchTool"
VERSION="1.1.1"
INSTALL_DIR="/Applications"

# Pick a stable codesigning identity if one exists; otherwise fall back to
# ad-hoc (and warn that permissions WILL reset every build).
SIGN_IDENTITY="$(security find-identity -v -p codesigning \
  | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')"

echo "[1/6] Stopping running instances..."
pkill -f "${INSTALL_DIR}/${APP}" 2>/dev/null || true
pkill -f "${INSTALL_DIR}/BetterTouch.app" 2>/dev/null || true   # old name
pkill -f ".build/debug/${EXEC}" 2>/dev/null || true
pkill -f ".build/release/${EXEC}" 2>/dev/null || true

echo "[2/6] Building release binary..."
swift build -c release

BIN="$(swift build -c release --show-bin-path)/${EXEC}"

echo "[3/6] Assembling ${APP}..."
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/${EXEC}"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>      <string>${EXEC}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleVersion</key>         <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

if [ -n "${SIGN_IDENTITY}" ]; then
    echo "[4/6] Code signing with stable identity: ${SIGN_IDENTITY}"
    echo "      (permissions persist across rebuilds)"
    codesign --force --sign "${SIGN_IDENTITY}" "${APP}"
else
    echo "[4/6] WARNING: no Apple Development / Developer ID identity found."
    echo "      Falling back to ad-hoc -- macOS WILL re-prompt for permissions"
    echo "      after every build. Create a signing identity to fix this."
    codesign --force --deep --sign - "${APP}"
fi

echo "[5/6] Clean install to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}/BetterTouch.app"   # remove the old-named app if present
rm -rf "${INSTALL_DIR}/${APP}"
cp -R "${APP}" "${INSTALL_DIR}/"

echo "[6/6] Launching..."
open "${INSTALL_DIR}/${APP}"
echo "Done. Running ${INSTALL_DIR}/${APP}"
