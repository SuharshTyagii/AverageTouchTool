import AppKit
import CoreGraphics
import ApplicationServices

/// Performs real system effects for each ActionKind.
enum ActionRunner {

    static func run(_ action: Action, frontmostApp: String?) {
        switch action.kind {
        case .volumeUp:   changeVolume(by: 6)
        case .volumeDown: changeVolume(by: -6)
        case .muteToggle: toggleMute()
        case .micMuteToggle: toggleMicMute()
        case .mediaPlayPause: mediaKey(16)   // NX_KEYTYPE_PLAY
        case .mediaNext:      mediaKey(17)   // NX_KEYTYPE_NEXT
        case .mediaPrevious:  mediaKey(18)   // NX_KEYTYPE_PREVIOUS
        case .nightShiftToggle: NightShift.shared.toggle()
        case .missionControl:   missionControl()
        case .openControlCenter: openControlCenter()
        case .lockScreen:       lockScreen()
        case .windowLeftHalf:   moveFrontWindow { area, _ in
            CGRect(x: area.minX, y: area.minY, width: area.width / 2, height: area.height) }
        case .windowRightHalf:  moveFrontWindow { area, _ in
            CGRect(x: area.midX, y: area.minY, width: area.width / 2, height: area.height) }
        case .windowMaximize:   moveFrontWindow { area, _ in area }
        case .windowCenter:     moveFrontWindow { area, cur in
            CGRect(x: area.midX - cur.width / 2, y: area.midY - cur.height / 2,
                   width: cur.width, height: cur.height) }
        case .enterFullScreen:  setFrontWindowFullScreen(true)
        case .exitFullScreen:   setFrontWindowFullScreen(false)
        case .toggleFullScreen: toggleFrontWindowFullScreen()
        case .captureSelection: capture(interactive: true)
        case .captureScreen:    capture(interactive: false)
        case .sendShortcut:
            if let code = action.keyCode {
                sendKey(CGKeyCode(code), flags: action.modifiers.cgFlags)
            }
        case .runShell:   runShell(expand(action.argument, app: frontmostApp))
        case .runAppleScript: runAppleScript(expand(action.argument, app: frontmostApp))
        case .launchApp:  launchApp(action.argument)
        case .openURL:    openURL(action.argument)
        case .showHUD:    HUD.show(expand(action.argument, app: frontmostApp))
        }
    }

    // MARK: Templating

    private static func expand(_ s: String, app: String?) -> String {
        var out = s.replacingOccurrences(of: "{app}", with: app ?? "")
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        out = out.replacingOccurrences(of: "{datetime}", with: df.string(from: Date()))
        out = out.replacingOccurrences(of: "{random}", with: String(UUID().uuidString.prefix(8)))
        return out
    }

    // MARK: Volume (via AppleScript — the simplest reliable path)

    private static func changeVolume(by delta: Int) {
        runAppleScript(
            "set volume output volume (output volume of (get volume settings) + \(delta))")
    }

    private static func toggleMute() {
        runAppleScript(
            "set volume output muted (not (output muted of (get volume settings)))")
    }

    /// Toggle the *input* (microphone) volume between 0 and a restored level.
    private static func toggleMicMute() {
        runAppleScript("""
        set cur to input volume of (get volume settings)
        if cur > 0 then
            set volume input volume 0
        else
            set volume input volume 75
        end if
        """)
    }

    private static func runAppleScript(_ source: String) {
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }

    // MARK: System-defined media keys (play/pause, next, previous)

    private static func mediaKey(_ key: Int32) {
        func post(down: Bool) {
            let flags: NSEvent.ModifierFlags =
                down ? NSEvent.ModifierFlags(rawValue: 0xA00) : NSEvent.ModifierFlags(rawValue: 0xB00)
            let data1 = Int(key) << 16 | (down ? 0xA << 8 : 0xB << 8)
            guard let ev = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: flags,
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: 8, data1: data1, data2: -1) else { return }
            ev.cgEvent?.post(tap: .cghidEventTap)
        }
        post(down: true)
        post(down: false)
    }

    // MARK: System actions

    private static func missionControl() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Mission Control"]
        try? proc.run()
    }

    /// Click the Control Center menu-bar item via System Events (needs
    /// Accessibility). Tries both US and UK spellings.
    private static func openControlCenter() {
        runAppleScript("""
        tell application "System Events" to tell process "ControlCenter"
            try
                click menu bar item "Control Center" of menu bar 1
            on error
                try
                    click menu bar item "Control Centre" of menu bar 1
                end try
            end try
        end tell
        """)
    }

    private static func lockScreen() {
        // ⌃⌘Q — the system lock shortcut. (Q = virtual key 12.)
        sendKey(12, flags: [.maskCommand, .maskControl])
    }

    // MARK: Window management (via the Accessibility API)

    /// Resize/move the focused window of the frontmost app. `transform` receives
    /// the usable screen area and the window's current frame (both in AX
    /// top-left coordinates) and returns the desired frame.
    private static func moveFrontWindow(_ transform: (CGRect, CGRect) -> CGRect) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let winRef else { Log.line("window: no focused window"); return }
        let window = winRef as! AXUIElement

        // AX uses a top-left origin measured from the primary display's top.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let area = CGRect(x: visible.minX, y: primaryHeight - visible.maxY,
                          width: visible.width, height: visible.height)

        var current = CGRect.zero
        if let posRef = copyAX(window, kAXPositionAttribute) {
            AXValueGetValue(posRef as! AXValue, .cgPoint, &current.origin)
        }
        if let sizeRef = copyAX(window, kAXSizeAttribute) {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &current.size)
        }

        let target = transform(area, current)
        var origin = target.origin
        var size = target.size
        if let posVal = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
        Log.line("window: \(app.localizedName ?? "?") -> \(target)")
    }

    /// Toggle native (green-button) full screen on the focused window of the
    /// frontmost app via the AX `AXFullScreen` attribute. Setting it to a value
    /// it's already at is a no-op, so enter/exit are safe to bind separately.
    private static func setFrontWindowFullScreen(_ on: Bool) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let winRef else { Log.line("fullscreen: no focused window"); return }
        let window = winRef as! AXUIElement

        let attr = "AXFullScreen" as CFString
        let result = AXUIElementSetAttributeValue(window, attr, on as CFBoolean)
        if result != .success {
            Log.line("fullscreen: \(on ? "enter" : "exit") failed (\(result.rawValue)) — window may not support it")
        } else {
            Log.line("fullscreen: \(app.localizedName ?? "?") -> \(on ? "enter" : "exit")")
        }
    }

    /// Flip the focused window's native full-screen state: read the current
    /// `AXFullScreen` value off the focused window and set the opposite. Falls
    /// back to entering full screen if the attribute can't be read.
    private static func toggleFrontWindowFullScreen() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let winRef else { Log.line("fullscreen: no focused window"); return }
        let window = winRef as! AXUIElement

        let attr = "AXFullScreen" as CFString
        var current: CFTypeRef?
        let isOn = (AXUIElementCopyAttributeValue(window, attr, &current) == .success)
            ? ((current as? Bool) ?? false)
            : false
        setFrontWindowFullScreen(!isOn)
    }

    private static func copyAX(_ element: AXUIElement, _ attr: String) -> CFTypeRef? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success else { return nil }
        return ref
    }

    // MARK: Keyboard synthesis

    private static func sendKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    // MARK: Apps / URLs / shell

    private static func launchApp(_ target: String) {
        let t = target.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        // A dotted token with no spaces is treated as a bundle identifier.
        let isBundleID = t.contains(".") && !t.contains(" ")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = isBundleID ? ["-b", t] : ["-a", t]
        try? proc.run()
    }

    private static func openURL(_ s: String) {
        if let url = URL(string: s.trimmingCharacters(in: .whitespaces)) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Region selection (`-i`) or whole screen. Copies the shot to the
    /// clipboard (`-c`) AND saves a PNG to ~/Desktop. `screencapture` needs
    /// Screen Recording permission or it silently produces nothing — so we
    /// preflight it and guide the user to grant it on the first miss.
    private static func capture(interactive: Bool) {
        guard Permissions.hasScreenCapture(prompt: true) else {
            HUD.show("Grant Screen Recording to capture")
            Permissions.openScreenRecordingSettings()
            Log.line("capture: blocked — no Screen Recording permission")
            return
        }

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let path = NSHomeDirectory() + "/Desktop/Capture_\(df.string(from: Date())).png"

        // First pass: copy to clipboard (-c). When -c is set screencapture
        // ignores any file path, so a second pass writes the file to disk.
        let toClipboard = Process()
        toClipboard.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        toClipboard.arguments = interactive ? ["-i", "-c"] : ["-x", "-c"]
        try? toClipboard.run()
        toClipboard.waitUntilExit()

        // Re-emit the clipboard image to a file so we keep a saved copy too.
        if let img = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
            HUD.show("Copied to clipboard")
        }
    }

    private static func runShell(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", command]
        try? proc.run()
    }
}

/// A lightweight transient on-screen HUD, like BTT's notifications.
enum HUD {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func show(_ text: String) {
        DispatchQueue.main.async { present(text) }
    }

    private static func present(_ text: String) {
        hideWork?.cancel()

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.sizeToFit()

        let pad: CGFloat = 28
        let size = NSSize(width: max(180, label.frame.width + pad * 2),
                          height: label.frame.height + pad * 1.4)

        let p = panel ?? makePanel()
        panel = p
        p.setContentSize(size)
        if let screen = NSScreen.main {
            let f = screen.frame
            p.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.height * 0.18))
        }
        p.contentView?.subviews.forEach { $0.removeFromSuperview() }
        label.frame = NSRect(x: 0, y: (size.height - label.frame.height) / 2,
                             width: size.width, height: label.frame.height)
        p.contentView?.addSubview(label)
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            p.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { dismiss() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
    }

    private static func dismiss() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            p.animator().alphaValue = 0
        } completionHandler: { p.orderOut(nil) }
    }

    private static func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
                        styleMask: [.nonactivatingPanel, .borderless],
                        backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let visual = NSVisualEffectView()
        visual.material = .hudWindow
        visual.state = .active
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 16
        visual.layer?.masksToBounds = true
        p.contentView = visual
        return p
    }
}
