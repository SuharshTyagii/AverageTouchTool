import Foundation
import CoreGraphics
import AppKit

// MARK: - Modifiers

struct Modifiers: Codable, Equatable, Hashable {
    var command = false
    var option = false
    var control = false
    var shift = false

    var isEmpty: Bool { !(command || option || control || shift) }

    var cgFlags: CGEventFlags {
        var f = CGEventFlags()
        if command { f.insert(.maskCommand) }
        if option { f.insert(.maskAlternate) }
        if control { f.insert(.maskControl) }
        if shift { f.insert(.maskShift) }
        return f
    }

    var symbols: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "")
    }

    static func from(cgFlags f: CGEventFlags) -> Modifiers {
        Modifiers(
            command: f.contains(.maskCommand),
            option: f.contains(.maskAlternate),
            control: f.contains(.maskControl),
            shift: f.contains(.maskShift)
        )
    }

    static func from(nsFlags f: NSEvent.ModifierFlags) -> Modifiers {
        Modifiers(
            command: f.contains(.command),
            option: f.contains(.option),
            control: f.contains(.control),
            shift: f.contains(.shift)
        )
    }
}

// MARK: - Triggers

enum TriggerKind: String, Codable, CaseIterable, Identifiable {
    case keyboardShortcut
    case swipe
    case tap
    case pinch
    case rotate
    var id: String { rawValue }
    var label: String {
        switch self {
        case .keyboardShortcut: return "Keyboard Shortcut"
        case .swipe: return "Trackpad Swipe"
        case .tap: return "Trackpad Tap"
        case .pinch: return "Pinch"
        case .rotate: return "Rotate"
        }
    }

    // Tolerant decode so configs written by older versions (e.g. a removed
    // `forceClick` trigger) still load instead of wiping the whole config.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TriggerKind(rawValue: raw) ?? .keyboardShortcut
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

enum SwipeDirection: String, Codable, CaseIterable, Identifiable {
    case up, down, left, right
    var id: String { rawValue }
    var arrow: String {
        switch self {
        case .up: return "↑"; case .down: return "↓"
        case .left: return "←"; case .right: return "→"
        }
    }
}

/// Pinch gesture direction. `pinchIn` = fingers move together (zoom out),
/// `pinchOut` = fingers spread apart (zoom in).
enum PinchDirection: String, Codable, CaseIterable, Identifiable {
    case pinchIn = "in"
    case pinchOut = "out"
    var id: String { rawValue }
    var label: String { self == .pinchIn ? "In (fingers together)" : "Out (fingers apart)" }
    var short: String { self == .pinchIn ? "In" : "Out" }
}

/// Two-finger rotation direction.
enum RotateDirection: String, Codable, CaseIterable, Identifiable {
    case clockwise
    case counterclockwise
    var id: String { rawValue }
    var label: String { self == .clockwise ? "Clockwise ↻" : "Counterclockwise ↺" }
    var short: String { self == .clockwise ? "↻" : "↺" }
}

struct Trigger: Codable, Equatable {
    var kind: TriggerKind
    // keyboardShortcut
    var keyCode: Int?
    var modifiers = Modifiers()
    // swipe / tap
    var direction: SwipeDirection?
    var fingers: Int?            // number of fingers for a swipe/tap (default 3)
    // pinch / rotate
    var pinch: PinchDirection?
    var rotate: RotateDirection?

    var fingerCount: Int { fingers ?? 3 }

    var summary: String {
        switch kind {
        case .keyboardShortcut:
            let key = keyCode.map { KeyNames.name(for: CGKeyCode($0)) } ?? "?"
            return modifiers.symbols + key
        case .swipe:
            return "\(fingerCount)-finger Swipe \(direction?.arrow ?? "?")"
        case .tap:
            return "\(fingerCount)-finger Tap"
        case .pinch:
            return "Pinch \(pinch?.short ?? "?")"
        case .rotate:
            return "Rotate \(rotate?.short ?? "?")"
        }
    }
}

// MARK: - Actions

/// Groups actions in the picker. `order` drives section ordering.
enum ActionCategory: String, CaseIterable, Identifiable {
    case window = "Window Management"
    case audio = "Audio & Media"
    case system = "System"
    case screenshots = "Screenshots"
    case launch = "Launch & Run"
    case keyboard = "Keyboard"
    case feedback = "Feedback"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .window: return "macwindow.on.rectangle"
        case .audio: return "speaker.wave.2.fill"
        case .system: return "gearshape.fill"
        case .screenshots: return "camera.viewfinder"
        case .launch: return "app.dashed"
        case .keyboard: return "keyboard.fill"
        case .feedback: return "bubble.left.fill"
        }
    }
}

enum ActionKind: String, Codable, CaseIterable, Identifiable {
    // Window management
    case windowLeftHalf, windowRightHalf, windowMaximize, windowCenter
    // Audio & media
    case volumeUp, volumeDown, muteToggle, micMuteToggle
    case mediaPlayPause, mediaNext, mediaPrevious
    // System
    case nightShiftToggle, missionControl, openControlCenter, lockScreen
    // Screenshots
    case captureSelection, captureScreen
    // Launch & run
    case launchApp, openURL, runShell, runAppleScript
    // Keyboard
    case sendShortcut
    // Feedback
    case showHUD
    var id: String { rawValue }

    var label: String {
        switch self {
        case .windowLeftHalf: return "Snap Left Half"
        case .windowRightHalf: return "Snap Right Half"
        case .windowMaximize: return "Maximize Window"
        case .windowCenter: return "Center Window"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .muteToggle: return "Toggle Mute"
        case .micMuteToggle: return "Toggle Mic Mute"
        case .mediaPlayPause: return "Play / Pause"
        case .mediaNext: return "Next Track"
        case .mediaPrevious: return "Previous Track"
        case .nightShiftToggle: return "Toggle Night Shift"
        case .missionControl: return "Mission Control"
        case .openControlCenter: return "Open Control Center"
        case .lockScreen: return "Lock Screen"
        case .captureSelection: return "Capture Selection (area)"
        case .captureScreen: return "Capture Whole Screen"
        case .launchApp: return "Launch App"
        case .openURL: return "Open URL"
        case .runShell: return "Run Shell Command"
        case .runAppleScript: return "Run AppleScript"
        case .sendShortcut: return "Send Keyboard Shortcut"
        case .showHUD: return "Show HUD Message"
        }
    }

    /// SF Symbol shown next to the action everywhere it appears.
    var icon: String {
        switch self {
        case .windowLeftHalf: return "rectangle.lefthalf.inset.filled"
        case .windowRightHalf: return "rectangle.righthalf.inset.filled"
        case .windowMaximize: return "arrow.up.left.and.arrow.down.right"
        case .windowCenter: return "rectangle.center.inset.filled"
        case .volumeUp: return "speaker.wave.3.fill"
        case .volumeDown: return "speaker.wave.1.fill"
        case .muteToggle: return "speaker.slash.fill"
        case .micMuteToggle: return "mic.slash.fill"
        case .mediaPlayPause: return "playpause.fill"
        case .mediaNext: return "forward.fill"
        case .mediaPrevious: return "backward.fill"
        case .nightShiftToggle: return "moon.fill"
        case .missionControl: return "square.grid.3x2.fill"
        case .openControlCenter: return "switch.2"
        case .lockScreen: return "lock.fill"
        case .captureSelection: return "selection.pin.in.out"
        case .captureScreen: return "camera.fill"
        case .launchApp: return "app.badge"
        case .openURL: return "globe"
        case .runShell: return "terminal.fill"
        case .runAppleScript: return "scroll.fill"
        case .sendShortcut: return "keyboard"
        case .showHUD: return "text.bubble.fill"
        }
    }

    var category: ActionCategory {
        switch self {
        case .windowLeftHalf, .windowRightHalf, .windowMaximize, .windowCenter:
            return .window
        case .volumeUp, .volumeDown, .muteToggle, .micMuteToggle,
             .mediaPlayPause, .mediaNext, .mediaPrevious:
            return .audio
        case .nightShiftToggle, .missionControl, .openControlCenter, .lockScreen:
            return .system
        case .captureSelection, .captureScreen:
            return .screenshots
        case .launchApp, .openURL, .runShell, .runAppleScript:
            return .launch
        case .sendShortcut:
            return .keyboard
        case .showHUD:
            return .feedback
        }
    }

    /// Free-text argument label, or nil if the action takes no text argument.
    var argumentLabel: String? {
        switch self {
        case .runShell: return "Command"
        case .runAppleScript: return "AppleScript source"
        case .launchApp: return "App name or bundle id"
        case .openURL: return "URL"
        case .showHUD: return "Message"
        default: return nil
        }
    }

    var usesKeyCombo: Bool { self == .sendShortcut }
}

struct Action: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: ActionKind
    var argument: String = ""
    // sendShortcut
    var keyCode: Int?
    var modifiers = Modifiers()

    var summary: String {
        switch kind {
        case .sendShortcut:
            let key = keyCode.map { KeyNames.name(for: CGKeyCode($0)) } ?? "?"
            return "Send \(modifiers.symbols)\(key)"
        case .launchApp:
            guard !argument.isEmpty else { return kind.label }
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: argument)?
                .deletingPathExtension().lastPathComponent ?? argument
            return "Launch \(name)"
        default:
            return argument.isEmpty ? kind.label : "\(kind.label): \(argument)"
        }
    }
}

// MARK: - Bindings & profiles

struct TriggerBinding: Codable, Identifiable, Equatable {
    var id = UUID()
    var trigger: Trigger
    var actions: [Action] = []
    var enabled = true
    /// Swallow the original event (keyboard only) so the app/OS never sees it.
    var consume = true
    var notes = ""
}

struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// nil => Global profile (always active). Otherwise active when this app is frontmost.
    var bundleID: String?
    var bindings: [TriggerBinding] = []

    var isGlobal: Bool { bundleID == nil }
}

struct Config: Codable {
    var profiles: [Profile]
    var touchBarItems: [TouchBarButton] = []

    // Backward-compatible decode: touchBarItems may be absent in older files.
    enum CodingKeys: String, CodingKey { case profiles, touchBarItems }
    init(profiles: [Profile], touchBarItems: [TouchBarButton] = []) {
        self.profiles = profiles
        self.touchBarItems = touchBarItems
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decode([Profile].self, forKey: .profiles)
        touchBarItems = try c.decodeIfPresent([TouchBarButton].self, forKey: .touchBarItems) ?? []
    }

    static var starter: Config {
        // Fresh installs start empty: a single Global profile with no bindings
        // and no Touch Bar items. The user builds everything from scratch.
        Config(profiles: [Profile(name: "Global", bundleID: nil, bindings: [])])
    }
}

// MARK: - Runtime event values

struct KeyEvent {
    var keyCode: CGKeyCode
    var modifiers: Modifiers
}

enum Gesture: Equatable {
    case swipe(SwipeDirection, fingers: Int)
    case tap(fingers: Int)
    case pinch(PinchDirection)
    case rotate(RotateDirection)
}

// MARK: - Touch Bar

enum TouchBarItemKind: String, Codable, CaseIterable, Identifiable {
    case button
    case slider
    var id: String { rawValue }
    var label: String { self == .button ? "Button" : "Slider" }
}

/// What a Touch Bar slider controls.
enum SliderTarget: String, Codable, CaseIterable, Identifiable {
    case nightShift
    var id: String { rawValue }
    var label: String {
        switch self { case .nightShift: return "Night Shift Intensity" }
    }
}

/// A custom Control Strip item, BTT-style. A `.button` runs actions on tap; a
/// `.slider` (e.g. Night Shift) shows a draggable slider in a popover. Both
/// support a custom label, SF Symbol or custom image icon, icon size, and
/// background color.
struct TouchBarButton: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: TouchBarItemKind = .button
    var title: String = "Button"
    var sfSymbol: String = ""
    var customIconPath: String = ""        // file path to a custom image, overrides symbol
    var iconSize: Double = 18              // points
    var backgroundColorHex: String = ""    // "#RRGGBB"; empty => default bezel
    var sliderTarget: SliderTarget = .nightShift
    var actions: [Action] = []

    init(id: UUID = UUID(), kind: TouchBarItemKind = .button, title: String = "Button",
         sfSymbol: String = "", customIconPath: String = "", iconSize: Double = 18,
         backgroundColorHex: String = "", sliderTarget: SliderTarget = .nightShift,
         actions: [Action] = []) {
        self.id = id; self.kind = kind; self.title = title; self.sfSymbol = sfSymbol
        self.customIconPath = customIconPath; self.iconSize = iconSize
        self.backgroundColorHex = backgroundColorHex; self.sliderTarget = sliderTarget
        self.actions = actions
    }

    // Backward-compatible decode: new fields default when absent in older files.
    enum CodingKeys: String, CodingKey {
        case id, kind, title, sfSymbol, customIconPath, iconSize, backgroundColorHex, sliderTarget, actions
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(TouchBarItemKind.self, forKey: .kind) ?? .button
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Button"
        sfSymbol = try c.decodeIfPresent(String.self, forKey: .sfSymbol) ?? ""
        customIconPath = try c.decodeIfPresent(String.self, forKey: .customIconPath) ?? ""
        iconSize = try c.decodeIfPresent(Double.self, forKey: .iconSize) ?? 18
        backgroundColorHex = try c.decodeIfPresent(String.self, forKey: .backgroundColorHex) ?? ""
        sliderTarget = try c.decodeIfPresent(SliderTarget.self, forKey: .sliderTarget) ?? .nightShift
        actions = try c.decodeIfPresent([Action].self, forKey: .actions) ?? []
    }
}
