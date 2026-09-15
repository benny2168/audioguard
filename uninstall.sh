#!/usr/bin/env bash
set -e

APP_NAME="AudioGuard"
APP_BUNDLE="/Applications/${APP_NAME}.app"

echo "Uninstalling ${APP_NAME}..."
killall "${APP_NAME}" >/dev/null 2>&1 || true
rm -rf "${APP_BUNDLE}"
defaults delete com.benabraham.AudioGuard >/dev/null 2>&1 || true

echo "✅ ${APP_NAME} has been completely uninstalled."
