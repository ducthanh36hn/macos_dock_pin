import Cocoa
import CoreGraphics

// CGEvent tap — intercepts mouse moved events and pushes the cursor back
// when it reaches the Dock trigger zone on any non-pinned screen.
class DockMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isEnabled = false

    var pinnedScreen: NSScreen? = NSScreen.main {
        didSet { log("Pinned screen changed to: \(pinnedScreen?.localizedName ?? "nil")") }
    }

    // Dock activates within the last ~2px of a screen edge.
    private let edgeThreshold: CGFloat = 2.0
    // Push cursor this many px away from the edge when blocked.
    private let pushback: CGFloat = 5.0

    func start() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            isEnabled = true
            return
        }

        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log("Failed to create event tap — Accessibility permission required")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true
        log("Event tap started")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        isEnabled = false
        log("Event tap stopped")
    }

    func tearDown() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isEnabled = false
    }

    // Called from the C callback. Returns nil to swallow the event, or a
    // (possibly new) event to let through.
    func processEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if macOS disabled it due to latency (raw values 0xFFFFFFFE / 0xFFFFFFFD).
        if type.rawValue == 0xFFFFFFFE || type.rawValue == 0xFFFFFFFD {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return nil
        }

        guard isEnabled, let pinned = pinnedScreen else {
            return Unmanaged.passRetained(event)
        }

        let cursor = event.location
        let orientation = dockOrientation()

        for screen in NSScreen.screens {
            guard screen != pinned,
                  let bounds = cgBounds(of: screen),
                  bounds.contains(cursor),
                  isInTriggerZone(cursor, bounds: bounds, orientation: orientation)
            else { continue }

            let safe = safePosition(from: cursor, bounds: bounds, orientation: orientation)
            CGWarpMouseCursorPosition(safe)

            // Return a synthetic event at the safe position so downstream
            // apps (including the Dock) see the adjusted location.
            let src = CGEventSource(stateID: .combinedSessionState)
            if let replacement = CGEvent(
                mouseEventSource: src,
                mouseType: .mouseMoved,
                mouseCursorPosition: safe,
                mouseButton: .left
            ) {
                replacement.flags = event.flags
                return Unmanaged.passRetained(replacement)
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Private helpers

    private func isInTriggerZone(_ p: CGPoint, bounds: CGRect, orientation: String) -> Bool {
        switch orientation {
        case "left":  return p.x <= bounds.minX + edgeThreshold
        case "right": return p.x >= bounds.maxX - edgeThreshold
        default:      return p.y >= bounds.maxY - edgeThreshold  // bottom (CGCoords: y↓)
        }
    }

    private func safePosition(from p: CGPoint, bounds: CGRect, orientation: String) -> CGPoint {
        var q = p
        switch orientation {
        case "left":  q.x = bounds.minX + edgeThreshold + pushback
        case "right": q.x = bounds.maxX - edgeThreshold - pushback
        default:      q.y = bounds.maxY - edgeThreshold - pushback
        }
        return q
    }

    // Returns display bounds in Quartz/CGEvent coordinate space (top-left origin, y↓).
    private func cgBounds(of screen: NSScreen) -> CGRect? {
        guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDisplayBounds(n.uint32Value)
    }

    private func dockOrientation() -> String {
        UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom"
    }

    private func log(_ msg: String) {
        print("[DockPin] \(msg)")
    }
}

// Must be a free C function — cannot be a closure capturing self.
private func eventTapCallback(
    proxy _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let monitor = Unmanaged<DockMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.processEvent(type: type, event: event)
}
