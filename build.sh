#!/usr/bin/env bash
set -e

mkdir -p build/AudioGuard.app/Contents/MacOS
mkdir -p build/AudioGuard.app/Contents/Resources

cp src/Info.plist build/AudioGuard.app/Contents/Info.plist

swiftc -O src/main.swift \
    -o build/AudioGuard.app/Contents/MacOS/AudioGuard \
    -framework Cocoa \
    -framework CoreAudio \
    -framework UserNotifications \
    -framework ServiceManagement

codesign -s - --force build/AudioGuard.app

echo "✅ Built: build/AudioGuard.app"
