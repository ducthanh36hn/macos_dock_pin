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

## Build

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode 15+.

```bash
git clone https://github.com/ducthanh36hn/macos_dock_pin.git
cd macos_dock_pin
xcodegen generate
xcodebuild -scheme DockPin -configuration Release build
```

Or open `DockPin.xcodeproj` in Xcode and run from there.

## First launch

1. Open `DockPin.app`
2. Click the **⚠️ Grant Accessibility Permission** menu item
3. Enable DockPin in *System Settings → Privacy & Security → Accessibility*
4. The app automatically relaunches once permission is detected
5. Select the screen to pin the Dock to via **Pin Dock to Screen**
