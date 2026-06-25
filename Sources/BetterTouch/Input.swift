import AppKit
import CoreGraphics

// MARK: - Permissions

enum Permissions {
    /// Accessibility / Input Monitoring trust. Pass prompt=true to ask the OS
    /// to surface the System Settings pane.
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Screen Recording trust — required for `screencapture` to produce real
    /// pixels (otherwise the capture is blank/silently fails). Returns whether
    /// access is currently granted; pass prompt=true to ask the OS for it.
    static func hasScreenCapture(prompt: Bool) -> Bool {
        if prompt { return CGRequestScreenCaptureAccess() }
        return CGPreflightScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Keyboard event tap

/// Intercepts global keyDown events. The handler returns true to CONSUME the
/// event (so the keystroke never reaches the focused app), false to pass it on.
final class KeyboardTap {
    /// Return true to consume.
    var onKey: ((KeyEvent, Bool) -> Bool)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Returns false if the tap could not be created (missing permission).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // C function pointer: capture nothing; recover `self` via refcon.
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<KeyboardTap>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }

        // Tap at the HID level (not session level): events here are seen BEFORE
        // the WindowServer processes system "symbolic hotkeys" like ⌃→ "switch
        // Space" / Mission Control. A session-level tap runs *after* that, so
        // consuming ⌃→ there couldn't stop the Space switch. At the HID level our
        // `return nil` actually suppresses it, so remaps of system shortcuts win.
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.line("keyboard tap: FAILED to create HID tap (check Input Monitoring/Accessibility)")
            return false
        }
        Log.line("keyboard tap: created at HID level")

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-arm if the OS disabled the tap.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // Auto-repeat (held key) is still routed to the matcher so a bound combo
        // stays consumed for the whole hold. Otherwise repeats leak through to
        // the system — e.g. a held ⌃→ remap leaks to the "switch Space" hotkey.
        // `isRepeat` lets the engine re-fire only repeat-safe actions.
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let mods = Modifiers.from(cgFlags: event.flags)
        let consumed = onKey?(KeyEvent(keyCode: keyCode, modifiers: mods), isRepeat) ?? false
        // Diagnostic: log modified keystrokes only (avoid logging plain typing),
        // and skip repeat spam so the log stays readable.
        if !mods.isEmpty && !isRepeat {
            Log.line("key: \(mods.symbols)\(KeyNames.name(for: keyCode)) (code=\(keyCode)) consumed=\(consumed)")
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
    }
}
