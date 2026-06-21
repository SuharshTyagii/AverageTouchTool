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
    var onKey: ((KeyEvent) -> Bool)?

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

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

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

        // Ignore auto-repeat so a held key fires once.
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let mods = Modifiers.from(cgFlags: event.flags)
        let consumed = onKey?(KeyEvent(keyCode: keyCode, modifiers: mods)) ?? false
        // Diagnostic: log modified keystrokes only (avoid logging plain typing).
        if !mods.isEmpty {
            Log.line("key: \(mods.symbols)\(KeyNames.name(for: keyCode)) (code=\(keyCode)) consumed=\(consumed)")
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
    }
}
