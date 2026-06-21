import SwiftUI
import AppKit

/// Create or edit a single binding: pick a trigger, then one action.
/// (The data model supports multiple actions; the editor exposes one for now.)
struct BindingEditor: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID
    let existing: TriggerBinding?

    @State private var triggerKind: TriggerKind = .keyboardShortcut
    @State private var shortcutKeyCode: Int?
    @State private var shortcutMods = Modifiers()
    @State private var direction: SwipeDirection = .up
    @State private var fingers: Int = 3
    @State private var pinch: PinchDirection = .pinchIn
    @State private var rotate: RotateDirection = .clockwise

    @State private var actionKind: ActionKind = .sendShortcut
    @State private var argument = ""
    @State private var actionKeyCode: Int?
    @State private var actionMods = Modifiers()
    @State private var consume = true
    @State private var recording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Binding" : "Edit Binding")
                .font(.title3).bold()

            // ---- Trigger ----
            GroupBox("When this happens") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Picker("Trigger", selection: $triggerKind) {
                            ForEach(TriggerKind.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu)

                        // Recording only makes sense for trackpad gestures.
                        if triggerKind != .keyboardShortcut {
                            if recording {
                                Label("Do a gesture…", systemImage: "dot.radiowaves.left.and.right")
                                    .foregroundStyle(.red).font(.callout)
                                Button("Cancel") { cancelRecord() }
                            } else {
                                Button {
                                    startRecord()
                                } label: {
                                    Label("Record", systemImage: "hand.draw")
                                }
                                .help("Record a gesture: perform a trackpad swipe, tap, pinch, or rotate and it fills in the trigger above automatically.")
                            }
                        }
                    }

                    switch triggerKind {
                    case .keyboardShortcut:
                        ShortcutRecorder(keyCode: $shortcutKeyCode, modifiers: $shortcutMods)
                        Toggle("Block the original shortcut (consume the key)", isOn: $consume)
                            .font(.callout)
                    case .swipe:
                        Picker("Fingers", selection: $fingers) {
                            ForEach(2...4, id: \.self) { Text("\($0) fingers").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Direction", selection: $direction) {
                            ForEach(SwipeDirection.allCases) { Text("\($0.arrow) \($0.rawValue)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    case .tap:
                        Picker("Fingers", selection: $fingers) {
                            ForEach(2...5, id: \.self) { Text("\($0) fingers").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text("Fires on a quick stationary tap. Single-finger taps are excluded so normal clicking still works.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .pinch:
                        Picker("Direction", selection: $pinch) {
                            ForEach(PinchDirection.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text("Two-finger pinch.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .rotate:
                        Picker("Direction", selection: $rotate) {
                            ForEach(RotateDirection.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text("Two-finger rotation.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }

            // ---- Action ----
            GroupBox("Do this") {
                VStack(alignment: .leading, spacing: 10) {
                    ActionPicker(selection: $actionKind)

                    if actionKind == .launchApp {
                        Text("App to launch:").font(.callout)
                        AppPickerButton(bundleID: $argument)
                    } else if let label = actionKind.argumentLabel {
                        TextField(label, text: $argument)
                            .textFieldStyle(.roundedBorder)
                    }
                    if actionKind.usesKeyCombo {
                        Text("Keystroke to send:").font(.callout)
                        ShortcutRecorder(keyCode: $actionKeyCode, modifiers: $actionMods)
                    }
                    if actionKind == .runShell || actionKind == .showHUD {
                        Text("Tokens: {app} {datetime} {random}")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear(perform: load)
        .onDisappear { Engine.shared.gestureRecorder = nil }
    }

    // MARK: Gesture recording

    private func startRecord() {
        recording = true
        Engine.shared.gestureRecorder = { gesture in
            apply(gesture)
            recording = false
        }
    }

    private func cancelRecord() {
        Engine.shared.gestureRecorder = nil
        recording = false
    }

    /// Map a captured gesture onto the trigger fields.
    private func apply(_ gesture: Gesture) {
        switch gesture {
        case .swipe(let dir, let f): triggerKind = .swipe; direction = dir; fingers = f
        case .tap(let f):            triggerKind = .tap; fingers = f
        case .pinch(let d):          triggerKind = .pinch; pinch = d
        case .rotate(let d):         triggerKind = .rotate; rotate = d
        }
    }

    private var isValid: Bool {
        switch triggerKind {
        case .keyboardShortcut: return shortcutKeyCode != nil
        default: return true
        }
    }

    private func load() {
        guard let b = existing else { return }
        triggerKind = b.trigger.kind
        shortcutKeyCode = b.trigger.keyCode
        shortcutMods = b.trigger.modifiers
        direction = b.trigger.direction ?? .up
        fingers = b.trigger.fingerCount
        pinch = b.trigger.pinch ?? .pinchIn
        rotate = b.trigger.rotate ?? .clockwise
        consume = b.consume
        if let a = b.actions.first {
            actionKind = a.kind
            argument = a.argument
            actionKeyCode = a.keyCode
            actionMods = a.modifiers
        }
    }

    private func save() {
        var trigger = Trigger(kind: triggerKind)
        switch triggerKind {
        case .keyboardShortcut:
            trigger.keyCode = shortcutKeyCode
            trigger.modifiers = shortcutMods
        case .swipe:
            trigger.direction = direction
            trigger.fingers = fingers
        case .tap:
            trigger.fingers = fingers
        case .pinch:
            trigger.pinch = pinch
        case .rotate:
            trigger.rotate = rotate
        }

        var action = Action(kind: actionKind, argument: argument)
        if actionKind.usesKeyCombo {
            action.keyCode = actionKeyCode
            action.modifiers = actionMods
        }

        var binding = existing ?? TriggerBinding(trigger: trigger)
        binding.trigger = trigger
        binding.actions = [action]
        binding.consume = consume

        if existing == nil {
            store.addBinding(binding, toProfile: profileID)
        } else {
            store.updateBinding(binding, inProfile: profileID)
        }
        dismiss()
    }
}

// MARK: - Permissions banner

struct PermissionsBanner: View {
    @EnvironmentObject var engine: Engine
    @State private var trusted = Permissions.isTrusted(prompt: false)

    var body: some View {
        if !trusted || !engine.keyboardTapActive {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Input permissions needed").bold()
                    Text("Grant Accessibility & Input Monitoring so keyboard shortcuts can be captured.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Accessibility") { Permissions.openAccessibilitySettings() }
                Button("Input Monitoring") { Permissions.openInputMonitoringSettings() }
                Button("Recheck") {
                    trusted = Permissions.isTrusted(prompt: false)
                    engine.retryKeyboardTap()
                }
            }
            .padding(10)
            .background(.orange.opacity(0.12))
        }
    }
}
