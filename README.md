# BetterTouch

A native macOS menu-bar automation app inspired by BetterTouchTool. It captures
**real** keyboard shortcuts and trackpad gestures and runs **real** system
actions, with per-app profiles and a SwiftUI config window.

Built as a Swift package (Swift 6.3 / macOS 14+). No Electron, no terminal — a
proper `NSApplication` menu-bar agent.

## Run it

**Option A — Xcode (recommended; permissions attribute cleanly):**
```bash
open /Users/mac/Documents/BetterTouch/Package.swift
```
Then press ▶ (the `BetterTouch` scheme). A menu-bar icon appears (hand/keyboard
glyph) — there's no Dock icon by design.

**Option B — terminal:**
```bash
cd /Users/mac/Documents/BetterTouch
swift run
```

## Grant permissions (required for keyboard capture)

macOS gates global input. On first launch the app requests Accessibility; you
also need Input Monitoring for the keyboard event tap:

1. Menu-bar icon → **Settings…** — the orange banner has buttons that jump
   straight to the right panes.
2. **System Settings → Privacy & Security → Accessibility** → enable BetterTouch
   (or Xcode, if running from Xcode).
3. **System Settings → Privacy & Security → Input Monitoring** → enable it too.
4. Back in the app, click **Recheck** (or "Retry keyboard capture" in the menu).

Trackpad swipes/force-click work without these (they use observe-only monitors).

## What it does

- **Menu-bar agent** with global enable/disable and a Settings window.
- **Keyboard shortcuts** — captured via `CGEventTap`; can **consume** the
  original keystroke (true remap) or pass it through.
- **Trackpad gestures** — 3-finger swipes (↑↓←→) and force-click, via public
  `NSEvent` monitors.
- **Per-app profiles** — a profile bound to a bundle id wins over Global when
  that app is frontmost (tracked through `NSWorkspace`).
- **Actions** — Volume Up/Down, Toggle Mute, Run Shell Command, Launch App,
  Open URL, Send Keyboard Shortcut, Show HUD. Shell/HUD support `{app}`,
  `{datetime}`, `{random}` tokens.
- **Live shortcut recorder** in the editor — click Record, press the combo.
- **Persistence** — `~/Library/Application Support/BetterTouch/config.json`
  (two example swipe→volume bindings ship preloaded).

## Try it

1. Settings → Global is selected → **Add Binding**.
2. Trigger: *Keyboard Shortcut* → **Record** → press e.g. ⌃⌥H.
3. Action: *Show HUD Message* → type `Hello from {app}` → **Save**.
4. Press ⌃⌥H anywhere → the HUD appears. Toggle "Block the original shortcut"
   to see consume vs. passthrough.
5. **Add App Profile** (e.g. `com.apple.Safari`), add a binding there, and watch
   the same trigger behave differently when Safari is frontmost.

## Honest limitations (current slice)

- **No Touch Bar UI.** Apple removed the Touch Bar; there's no hardware/API on
  this machine, so it's intentionally omitted. A floating widget bar is the
  natural replacement and is the obvious next addition.
- **Gestures are public-API only** — swipe + force-click. Distinct finger-count
  taps/pinch-magnitude need the private MultitouchSupport framework; not wired
  yet.
- **One action per binding in the editor.** The model stores an action *list*;
  the UI currently exposes the first. Multi-action sequences are a small UI add.
- Conditions (time/window-title) exist conceptually in the design but aren't in
  this build yet — profiles currently key off frontmost app only.

## Layout

```
Sources/BetterTouch/
  App.swift            @main App + AppDelegate + menu-bar menu
  Models.swift         Trigger / Action / TriggerBinding / Profile / Config
  ConfigStore.swift    persistence + binding resolution (app profile > global)
  Engine.swift         input → resolve → run; frontmost-app tracking
  Input.swift          CGEventTap (keyboard) + NSEvent monitors (gestures) + permissions
  Actions.swift        real system effects + HUD overlay
  SettingsUI.swift     three-pane editor (profiles ▸ bindings)
  BindingEditor.swift  trigger+action editor, permissions banner
  ShortcutRecorder.swift  live keystroke capture
  KeyNames.swift       key code → label
```
