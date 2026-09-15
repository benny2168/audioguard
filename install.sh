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
    SRC_FILE="${SCRIPT_DIR}/src/main.swift"
    PLIST_FILE="${SCRIPT_DIR}/src/Info.plist"
else
    echo "🌐 Downloading latest source from GitHub..."
    SRC_FILE="${TEMP_DIR}/main.swift"
    PLIST_FILE="${TEMP_DIR}/Info.plist"
    curl -fsSL "https://raw.githubusercontent.com/benny2168/audioguard/main/src/main.swift" -o "${SRC_FILE}"
    curl -fsSL "https://raw.githubusercontent.com/benny2168/audioguard/main/src/Info.plist" -o "${PLIST_FILE}"
fi

# 3. Create App Bundle
echo "📦 Building ${APP_NAME}.app..."
mkdir -p "${TEMP_DIR}/${APP_NAME}.app/Contents/MacOS"
mkdir -p "${TEMP_DIR}/${APP_NAME}.app/Contents/Resources"

cp "${PLIST_FILE}" "${TEMP_DIR}/${APP_NAME}.app/Contents/Info.plist"

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

# 7. Install to /Applications
echo "🚀 Installing to ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
cp -R "${TEMP_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/"

# 8. Launch App
open "${APP_BUNDLE}"

echo "========================================"
echo "✅ AudioGuard successfully installed!"
echo "Look for the speaker icon in your Menu Bar."
echo "========================================"
