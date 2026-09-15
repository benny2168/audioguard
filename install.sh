#!/usr/bin/env bash
set -e

# AudioGuard Installer for macOS
# Repository: https://github.com/benny2168/audioguard

echo "========================================"
echo "      Installing AudioGuard for macOS   "
echo "========================================"

APP_NAME="AudioGuard"
INSTALL_DIR="/Applications"
APP_BUNDLE="${INSTALL_DIR}/${APP_NAME}.app"
TEMP_DIR=$(mktemp -d /tmp/audioguard_build.XXXXXX)

cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# 1. Check for Swift compiler
if ! command -v swiftc >/dev/null 2>&1; then
    echo "❌ Error: 'swiftc' is required. Please install Xcode Command Line Tools by running:"
    echo "   xcode-select --install"
    exit 1
fi

# 2. Determine source location (local directory or remote download)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ -f "${SCRIPT_DIR}/src/main.swift" ] && [ -f "${SCRIPT_DIR}/src/Info.plist" ]; then
    echo "📁 Using local source files from ${SCRIPT_DIR}/src..."
    SRC_DIR="${SCRIPT_DIR}"
else
    echo "🌐 Downloading latest release directly from GitHub..."
    SRC_DIR="${TEMP_DIR}/source"
    mkdir -p "${SRC_DIR}"
    curl -fsSL "https://github.com/benny2168/audioguard/archive/refs/heads/main.tar.gz" | tar -xzf - -C "${SRC_DIR}" --strip-components=1
fi

SRC_FILE="${SRC_DIR}/src/main.swift"
PLIST_FILE="${SRC_DIR}/src/Info.plist"
ICON_FILE="${SRC_DIR}/src/AppIcon.icns"

# 3. Create App Bundle
echo "📦 Building ${APP_NAME}.app..."
mkdir -p "${TEMP_DIR}/${APP_NAME}.app/Contents/MacOS"
mkdir -p "${TEMP_DIR}/${APP_NAME}.app/Contents/Resources"

cp "${PLIST_FILE}" "${TEMP_DIR}/${APP_NAME}.app/Contents/Info.plist"
if [ -f "${ICON_FILE}" ]; then
    cp "${ICON_FILE}" "${TEMP_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns"
fi

# 4. Compile Swift Binary
swiftc -O "${SRC_FILE}" \
    -o "${TEMP_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" \
    -framework Cocoa \
    -framework CoreAudio \
    -framework UserNotifications \
    -framework ServiceManagement

# 5. Ad-hoc Codesign
codesign -s - --force "${TEMP_DIR}/${APP_NAME}.app" >/dev/null 2>&1 || true

# 6. Stop running instance if present
killall "${APP_NAME}" >/dev/null 2>&1 || true
sleep 1

# 7. Install to /Applications
echo "🚀 Installing to ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
cp -R "${TEMP_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/"

# 8. Launch App
open "${APP_BUNDLE}" 2>/dev/null || open -a "${APP_BUNDLE}" 2>/dev/null || "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" &

echo "========================================"
echo "✅ AudioGuard successfully installed!"
echo "Look for the speaker icon in your Menu Bar."
echo "========================================"
