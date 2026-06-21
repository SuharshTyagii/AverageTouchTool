import AppKit
import Combine

/// Ties the input layer to the config and the action runner. Tracks the
/// frontmost app so per-app profiles resolve, exactly like BetterTouchTool.
final class Engine: ObservableObject {
    static let shared = Engine()

    private let store = ConfigStore.shared
    private let keyboard = KeyboardTap()

    @Published private(set) var frontmostBundleID: String?
    @Published private(set) var frontmostName: String?
    @Published private(set) var keyboardTapActive = false
    @Published private(set) var multitouchActive = false

    var touchBarAvailable: Bool { DFR.isAvailable }

    /// When set, the next keyDown is delivered here (and swallowed) instead of
    /// being matched against bindings. The shortcut recorder uses this so it can
    /// capture combos the WindowServer steals before they reach a local NSEvent
    /// monitor (e.g. ⌃← / ⌃→, which macOS routes to Mission Control spaces).
    var keyRecorder: ((KeyEvent) -> Void)?

    /// When set, the next detected trackpad gesture is delivered here instead of
    /// being matched against bindings. The binding editor's "Record Gesture"
    /// button uses this to capture a gesture and pre-fill the trigger.
    var gestureRecorder: ((Gesture) -> Void)?

    private var configCancellable: AnyCancellable?

    private init() {}

    func start() {
        keyboard.onKey = { [weak self] key in self?.handleKey(key) ?? false }
        MultitouchGesture.shared.onSwipe = { [weak self] dir, fingers in
            self?.handleGesture(.swipe(dir, fingers: fingers))
        }
        MultitouchGesture.shared.onTap = { [weak self] fingers in
            self?.handleGesture(.tap(fingers: fingers))
        }
        MultitouchGesture.shared.onPinch = { [weak self] dir in
            self?.handleGesture(.pinch(dir))
        }
        MultitouchGesture.shared.onRotate = { [weak self] dir in
            self?.handleGesture(.rotate(dir))
        }

        keyboardTapActive = keyboard.start()
        multitouchActive = MultitouchGesture.shared.start()
        observeFrontmostApp()

        Log.line("engine start: keyboardTap=\(keyboardTapActive) multitouch=\(multitouchActive) " +
                 "touchBar=\(DFR.isAvailable) nightShift=\(NightShift.shared.isAvailable) " +
                 "accessibilityTrusted=\(Permissions.isTrusted(prompt: false))")

        // Build the Touch Bar now and whenever the config changes. `$config`
        // fires immediately with the current value, so dropFirst() avoids a
        // duplicate rebuild at startup (which raced the control-strip items).
        TouchBarController.shared.rebuild(from: store.config.touchBarItems)
        configCancellable = store.$config.dropFirst().sink { cfg in
            TouchBarController.shared.rebuild(from: cfg.touchBarItems)
        }
    }

    /// Try to (re)create the keyboard tap, e.g. after the user grants permission.
    func retryKeyboardTap() {
        keyboardTapActive = keyboard.start()
    }

    // MARK: Frontmost app tracking

    private func observeFrontmostApp() {
        updateFrontmost(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.updateFrontmost(app)
        }
    }

    private func updateFrontmost(_ app: NSRunningApplication?) {
        frontmostBundleID = app?.bundleIdentifier
        frontmostName = app?.localizedName
    }

    // MARK: Event handling

    private func handleKey(_ key: KeyEvent) -> Bool {
        // Recording mode: hand the keystroke to the recorder and swallow it so
        // the underlying combo (e.g. ⌃→ space switch) doesn't also fire.
        if let recorder = keyRecorder {
            keyRecorder = nil
            DispatchQueue.main.async { recorder(key) }
            return true
        }
        guard store.globallyEnabled else { return false }
        for binding in store.activeBindings(frontmostBundleID: frontmostBundleID)
        where binding.enabled && binding.trigger.kind == .keyboardShortcut {
            if binding.trigger.keyCode == Int(key.keyCode),
               binding.trigger.modifiers == key.modifiers {
                fire(binding)
                return binding.consume
            }
        }
        return false
    }

    private func handleGesture(_ gesture: Gesture) {
        // Recording mode: hand the gesture to the recorder and don't fire any
        // binding for it.
        if let recorder = gestureRecorder {
            gestureRecorder = nil
            DispatchQueue.main.async { recorder(gesture) }
            return
        }
        guard store.globallyEnabled else { return }
        for binding in store.activeBindings(frontmostBundleID: frontmostBundleID)
        where binding.enabled {
            switch (binding.trigger.kind, gesture) {
            case (.swipe, .swipe(let dir, let fingers))
                where binding.trigger.direction == dir && binding.trigger.fingerCount == fingers:
                fire(binding); return
            case (.tap, .tap(let fingers))
                where binding.trigger.fingerCount == fingers:
                fire(binding); return
            case (.pinch, .pinch(let dir))
                where binding.trigger.pinch == dir:
                fire(binding); return
            case (.rotate, .rotate(let dir))
                where binding.trigger.rotate == dir:
                fire(binding); return
            default:
                continue
            }
        }
    }

    private func fire(_ binding: TriggerBinding) {
        let app = frontmostName
        Log.line("fire: \(binding.trigger.summary) -> \(binding.actions.map(\.summary).joined(separator: ", "))")
        DispatchQueue.main.async {
            for action in binding.actions {
                ActionRunner.run(action, frontmostApp: app)
            }
        }
    }
}
