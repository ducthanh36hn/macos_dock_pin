import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    let monitor = DockMonitor()

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        observeScreenChanges()
        checkAccessibilityAndStart()
    }

    func applicationWillTerminate(_: Notification) {
        monitor.tearDown()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshMenuAndIcon()
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Accessibility

    private func checkAccessibilityAndStart() {
        if AXIsProcessTrusted() {
            monitor.start()
        } else {
            // Show the system prompt asking the user to grant access.
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            pollUntilTrusted()
        }
        refreshMenuAndIcon()
    }

    private func pollUntilTrusted() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            if AXIsProcessTrusted() {
                // Relaunch so CGEvent.tapCreate can succeed in the new process.
                self.relaunch()
            } else {
                self.pollUntilTrusted()
            }
        }
    }

    private func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.5; open '\(path)'"]
        task.launch()
        NSApp.terminate(nil)
    }

    // MARK: - Menu

    private func refreshMenuAndIcon() {
        updateIcon()
        buildMenu()
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let symbol: String
        if !AXIsProcessTrusted() {
            symbol = "exclamationmark.lock.fill"
        } else if monitor.isEnabled {
            symbol = "pin.fill"
        } else {
            symbol = "pin.slash.fill"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DockPin")
        button.image?.isTemplate = true
    }

    private func buildMenu() {
        let menu = NSMenu()

        if !AXIsProcessTrusted() {
            menu.addItem(makeItem("⚠️ Grant Accessibility Permission…", action: #selector(openAccessibilityPrefs)))
            menu.addItem(.separator())
        } else {
            // Toggle
            let enabled = monitor.isEnabled
            let toggleItem = makeItem(
                enabled ? "✓  Enabled" : "    Disabled",
                action: #selector(toggleMonitor)
            )
            toggleItem.state = enabled ? .on : .off
            menu.addItem(toggleItem)
            menu.addItem(.separator())

            // Screen picker (only shown when there are multiple screens)
            let screens = NSScreen.screens
            if screens.count > 1 {
                let sub = NSMenu()
                for (i, screen) in screens.enumerated() {
                    let item = makeItem(displayName(screen, index: i), action: #selector(selectScreen(_:)))
                    item.tag = i
                    item.state = (screen == monitor.pinnedScreen) ? .on : .off
                    sub.addItem(item)
                }
                let subParent = NSMenuItem(title: "Pin Dock to Screen", action: nil, keyEquivalent: "")
                subParent.submenu = sub
                menu.addItem(subParent)
                menu.addItem(.separator())
            } else {
                let info = NSMenuItem(title: "Only 1 display connected", action: nil, keyEquivalent: "")
                info.isEnabled = false
                menu.addItem(info)
                menu.addItem(.separator())
            }
        }

        // Launch at login
        let launchItem = makeItem("Launch at Login", action: #selector(toggleLaunchAtLogin))
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)
        menu.addItem(.separator())

        menu.addItem(makeItem("Quit DockPin", action: #selector(NSApplication.terminate(_:))))
        statusItem?.menu = menu
    }

    private func makeItem(_ title: String, action: Selector) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: "")
    }

    private func displayName(_ screen: NSScreen, index: Int) -> String {
        let name = screen.localizedName
        let tag = (screen == NSScreen.main) ? " (Main)" : ""
        return "\(name)\(tag)"
    }

    // MARK: - Actions

    @objc private func toggleMonitor() {
        if monitor.isEnabled { monitor.stop() } else { monitor.start() }
        refreshMenuAndIcon()
    }

    @objc private func selectScreen(_ sender: NSMenuItem) {
        let screens = NSScreen.screens
        guard sender.tag < screens.count else { return }
        monitor.pinnedScreen = screens[sender.tag]
        buildMenu()
    }

    @objc private func openAccessibilityPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Launch at Login

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("[DockPin] Launch at login error: \(error)")
        }
        buildMenu()
    }

    @objc private func screensDidChange() {
        // If the pinned screen was disconnected, fall back to main.
        if let pinned = monitor.pinnedScreen, !NSScreen.screens.contains(pinned) {
            monitor.pinnedScreen = NSScreen.main
        }
        refreshMenuAndIcon()
    }
}
