# AudioGuard Project Instructions

## Overview
AudioGuard is a native macOS menu bar utility written in Swift that monitors macOS CoreAudio routing, manages Jump Desktop virtual audio switching, and enforces user-defined fallback audio priorities.

## Architecture
- `src/main.swift`: Core application containing CoreAudio event listeners, Jump Desktop streaming detection engine, and AppKit NSStatusItem menu bar UI.
- `src/Info.plist`: Application bundle metadata (`LSUIElement = true`).
- `install.sh`: One-click local and remote installer that compiles with `swiftc`, codesigns, and installs to `/Applications/AudioGuard.app`.
- `build.sh`: Local build script.
- `uninstall.sh`: Uninstallation script.

## Core Rules & Patterns
- Zero external dependencies (uses standard macOS Swift, Cocoa, CoreAudio, UserNotifications, ServiceManagement).
- Ad-hoc codesigning enabled for frictionless local deployment without requiring an Apple Developer Team certificate.
