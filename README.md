# DockPin

A lightweight macOS menu bar app that keeps your Dock pinned to one screen when using multiple displays.

By default, macOS moves the Dock to whichever screen the cursor lingers at the bottom (or side) edge. DockPin intercepts those mouse events at the system level and pushes the cursor back, so the Dock never activates on screens you don't want it on.

## How it works

DockPin uses a **CGEvent tap** (`kCGHIDEventTap`) to monitor all mouse-moved events before they reach any application. When the cursor enters the 2px Dock-trigger zone on a non-pinned screen, DockPin warps the cursor back and replaces the event with a corrected position — the Dock never receives the trigger signal.

## Features

- Menu bar icon (`pin.fill`) — click to enable/disable at any time
- Choose which screen to pin the Dock to from the menu
- Automatically falls back to the main display if the pinned screen is disconnected
- **Launch at Login** toggle (uses `SMAppService`, no helper bundle needed)
- Handles Dock on bottom, left, or right (reads `com.apple.dock orientation`)

## Requirements

- macOS 13 Ventura or later
- **Accessibility permission** — required for the CGEvent tap to function  
  *(System Settings → Privacy & Security → Accessibility)*

## Install

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode 15+.

```bash
git clone https://github.com/ducthanh36hn/macos_dock_pin.git
cd macos_dock_pin
xcodegen generate
bash install.sh
```

`install.sh` builds a Release binary, installs it to `/Applications/DockPin.app`, and launches the app. It uses `rsync` instead of a full copy so macOS does not revoke the Accessibility permission on subsequent updates.

## First launch

1. Run `bash install.sh` — the app opens automatically
2. Click **⚠️ Grant Accessibility Permission** in the menu bar
3. Enable DockPin in *System Settings → Privacy & Security → Accessibility*
4. DockPin detects the permission and relaunches itself automatically
5. Select the screen to pin the Dock to via **Pin Dock to Screen**

> **Note:** Always use `install.sh` for updates. Replacing the `.app` bundle manually (rm + cp) causes macOS to revoke the Accessibility permission and you will need to re-grant it.
