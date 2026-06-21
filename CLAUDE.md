# AverageTouchTool — native macOS BetterTouchTool clone

A native **Swift macOS menu-bar app** that clones core BetterTouchTool (BTT)
behavior: global gesture/keyboard triggers running custom actions, per-app
profiles, and a customizable Touch Bar. This is a real AppKit/SwiftUI app — NOT
a design doc, web app, or scripting engine.

**Branding:** product name is **AverageTouchTool** (a deadpan riff on BTT).
This is the user-facing display name only — the SPM product/binary is still
`BetterTouch`, the bundle ID stays `com.suharsh.bettertouch`, and the config
dir stays `Application Support/BetterTouch`. Those are deliberately unchanged so
TCC permissions and existing configs persist (changing the bundle ID would reset
them). Being open-sourced and distributed directly (NOT the Mac App Store — the
private frameworks below make MAS impossible; same reason real BTT isn't there).

**Repo layout:** `Sources/` (the app), `web/` (static landing page —
plain HTML/CSS/JS, the "trackpad telemetry on graph paper" identity, with an
interactive detection pad), `video/` (Remotion promo video project). Each of
`web/` and `video/` has its own README.

## ⚠️ Hard constraints (do not break)

- **Do NOT touch the volume / 3-finger-swipe path.** It works and the user is
  explicit about leaving it alone. That means `Multitouch.swift`, and the
  `.swipe` handling in `Engine.swift` / `Input.swift`. Don't "improve" gesture
  detection.
- Keep it a native app. No TypeScript/Electron/terminal rewrites.
- The user picks Touch Bar items from a **list/picker** — never make them type
  bundle IDs or app names.

## Build & run

**Canonical workflow — ALWAYS use this after any code change.** One command:

```bash
# from the project root: /Users/mac/Documents/BetterTouch
./package.sh
```

`package.sh` now does everything: stops running instances → release build →
wraps it in `BetterTouch.app` (Info.plist with `LSUIElement` so it's menu-bar
only, stable bundle ID `com.suharsh.bettertouch`) → **code-signs with a stable
identity** → clean-installs to `/Applications` (`rm -rf` then `cp -R`) →
launches. The `.app` is gitignored.

`swift build` on its own is fine for a quick compile-check while iterating, but
the actual run/test pass must go through `./package.sh`.

### ⚠️ Code signing & why permissions used to keep re-prompting

macOS ties TCC permissions (Accessibility, Input Monitoring, Screen Recording)
to the app's **code signature**. **Ad-hoc signing does NOT work for this** — an
ad-hoc signature is just a content hash that changes on every build, so each
rebuild looks like a brand-new app and macOS re-prompts (the earlier claim that
ad-hoc "persists permissions" was wrong). `package.sh` therefore auto-detects a
stable identity (`Apple Development` / `Developer ID`, via `security
find-identity -p codesigning`) and signs with it; the signature stays constant
across rebuilds so permissions persist. It only falls back to ad-hoc (with a
warning) if no real identity exists. Current identity:
`Apple Development: suharsh96@gmail.com` (team `NJ7795VR2A`).

If permissions ever get stuck after a signing change, clear the stale TCC
entries and relaunch (the grant then binds to the new signature):

```bash
tccutil reset Accessibility com.suharsh.bettertouch
tccutil reset ListenEvent   com.suharsh.bettertouch   # Input Monitoring
tccutil reset ScreenCapture com.suharsh.bettertouch
```

- Swift Package (no `.xcodeproj`), `swift-tools` 6.0, `swiftLanguageMode(.v5)`
  for C-interop ergonomics. Target: macOS 14+. Built/tested on macOS 26.5,
  Swift 6.3, MacBookPro17,1 (M1, has a Touch Bar).
- Menu-bar agent: `MenuBarExtra` + `NSApp.setActivationPolicy(.accessory)`
  (no Dock icon).
- Runtime log: `/tmp/bettertouch.log` (via `Log.line`). Grep `TB:` / `MT:` /
  `fire:` / `engine start:` to see what's happening.
- Config (JSON): `~/Library/Application Support/BetterTouch/config.json`.
- Requires **Accessibility** + **Input Monitoring** permissions (prompted on
  launch via `AXIsProcessTrustedWithOptions`), plus **Screen Recording** for
  the capture actions (requested on first capture via
  `Permissions.hasScreenCapture` → `CGRequestScreenCaptureAccess`).

## Architecture

Input layer → `Engine` (resolves frontmost-app profile, matches triggers) →
`ActionRunner`. Touch Bar is a separate subsystem driven off the same config.

### Files (`Sources/BetterTouch/`)

- **App.swift** — `@main`, `AppDelegate` requests permissions + starts
  `Engine.shared`; menu-bar dropdown.
- **Models.swift** — data model. Key types: `Modifiers`, `Trigger`
  (`keyboardShortcut`/`swipe`/`tap`/`pinch`/`rotate`, with
  `fingers: Int?` → `fingerCount` default 3 for swipe+tap, plus
  `pinch: PinchDirection?` (`in`/`out`) and `rotate: RotateDirection?`
  (`clockwise`/`counterclockwise`)), `Action`/`ActionKind`. Each `ActionKind`
  has a `category: ActionCategory` (Window/Audio & Media/System/Screenshots/
  Launch & Run/Keyboard/Feedback) and an `icon` (SF Symbol) used by the picker.
  Actions: window snap (left/right half, maximize, center), volume, mute, mic
  mute, media play-pause/next/prev, nightShift, missionControl,
  openControlCenter, lockScreen, captureSelection/captureScreen, launchApp,
  openURL, runShell, runAppleScript, sendShortcut, showHUD. `TriggerBinding`
  (NOT named `Binding` — avoids SwiftUI clash),
  `Profile` (bundleID nil = Global), and Touch Bar types: `TouchBarItemKind`
  (`button`/`slider`), `SliderTarget` (`nightShift`), `TouchBarButton`
  (kind, title, sfSymbol, customIconPath, iconSize, backgroundColorHex,
  sliderTarget, actions — has backward-compatible `init(from:)` using
  `decodeIfPresent`). `Config.starter` seeds 3-finger swipe up/down → volume +
  a Capture button.
- **Engine.swift** — `ObservableObject`. Has `gestureRecorder: ((Gesture) ->
  Void)?` — when set, the next detected gesture is delivered there instead of
  firing a binding (mirrors `keyRecorder`); the binding editor's "Record" button
  uses it. Wires keyboard/gesture/multitouch
  callbacks, tracks frontmost app via `NSWorkspace`, rebuilds the Touch Bar on
  config changes (`store.$config.dropFirst().sink` — dropFirst avoids a
  duplicate startup rebuild that raced Control Strip items).
- **Input.swift** — `KeyboardTap` (CGEventTap, consume by returning nil,
  re-arms on tapDisabled), `Permissions` (Accessibility/Input Monitoring trust +
  `hasScreenCapture`/`openScreenRecordingSettings`). (Force-click /
  `GestureMonitor` was removed — it was confusing and unused.) `TriggerKind`
  decodes tolerantly (unknown raw values → `.keyboardShortcut`) so old configs
  with a removed kind don't wipe the whole config.
- **Multitouch.swift** — `MultitouchGesture.shared`. dlopen private
  **MultitouchSupport.framework** for raw finger-counted trackpad frames
  (`MTDeviceCreateList`/`MTRegisterContactFrameCallback`/`MTDeviceStart`). The C
  callback takes a raw pointer rebound via `assumingMemoryBound(to:)`.
  `deviceList` is retained for process lifetime (freeing it stops all frames).
  Detection: accumulate while ≥2 fingers down, decide direction on release from
  peak finger count + total travel (threshold 0.10). **Do not modify the swipe
  path (`handleFrame`).** (A distinct-`fingerID` counting experiment was tried to
  fix occasional 3-finger under-counting and REVERTED — `fingerID` isn't a stable
  per-finger id, so it over-counted and 2-finger swipes triggered 3-finger
  bindings. Peak `maxFingers` is the known-good behavior.) A separate `handleAdvanced` runs *alongside* it (called
  from the same `contactCallback`, read-only on the same frames, independent
  state) and detects taps / pinch / rotate: tracks first-finger-down → last-up,
  recording peak fingers, avg-position travel, and the 2-finger spread + angle.
  On release it classifies — big spread Δ (≥0.08) → pinch in/out; big angle Δ
  (≥0.45 rad) → rotate CW/CCW; else low travel (<0.05) + short duration (<0.4s)
  with ≥2 fingers → tap. Pinch/rotate use **dominance scoring** (each delta ÷ its
  threshold, fire the larger) so they don't steal each other's gestures. Fires
  `onTap`/`onPinch`/`onRotate` on the main thread. Single-finger taps are
  intentionally excluded so normal clicking still works.
  **Tap travel is measured only during the "all peak fingers down" phase**
  (rebased when more fingers land, lift-off frames ignored) — otherwise the
  centroid jump as fingers leave one-by-one faked travel and made 3/4-finger
  taps flaky. **Rotate angle delta is folded into ±90°**: the two-finger line is
  undirected, so a frame where the framework swaps finger order (π flip) reads as
  ~0 instead of a half-turn — this fixed rotate flakiness. Thresholds (top of
  `handleAdvanced`): tapTravel 0.06, tapMaxDuration 0.5s, pinch 0.06, rotate
  0.30 rad.
- **ActionPicker.swift** — `ActionPicker`: BTT-style action chooser used by
  both `BindingEditor` and `TouchBarEditor`. A bordered button (icon + current
  action) opens a `.popover` anchored to it with a search field + collapsible,
  icon-tagged `ActionCategory` sections. Searching force-expands all matching
  sections.
- **Actions.swift** — `ActionRunner.run`. Window snap/maximize/center use the
  **Accessibility API** (`AXUIElementCreateApplication` → focused window →
  set `kAXPosition`/`kAXSize`; AX uses a top-left origin off the primary
  display, converted from `NSScreen.visibleFrame`). Media keys via
  `NSEvent.otherEvent(.systemDefined, subtype: 8)`. Mic mute + Control Center +
  volume via AppleScript; Mission Control via `open -a "Mission Control"`; lock
  screen via ⌃⌘Q. captureSelection/captureScreen =
  `screencapture -i -c` / `-x -c` → **copies to clipboard**, then re-emits the
  clipboard image to `~/Desktop/Capture_<datetime>.png` (keeps both). Preflights
  Screen Recording permission first; on a miss shows a HUD + opens the pane.
  volume via AppleScript; keystrokes via
  CGEvent; launch/open/shell via Process. `HUD` overlay panel. Tokens: `{app}`,
  `{datetime}`, `{random}`.
- **NightShift.swift** — `NightShift.shared`. Private **CBBlueLightClient**
  (CoreBrightness) via `@objc` protocol + `unsafeBitCast`: `setStrength(_:commit:)`,
  `getStrength`, `setEnabled`. `apply(value)` clamps 0–1; ≤0.001 disables.
- **PrivateTouchBar.swift** — `DFR` enum. dlopen **DFRFoundation** +
  private NSTouchBar SPI: `setControlStripPresence`, `addSystemTrayItem:`,
  `presentSystemModalTouchBar:systemTrayItemIdentifier:` /
  `dismissSystemModalTouchBar:` (the modal API — confirmed available on macOS 26).
- **TouchBarController.swift** — **launcher + modal design** (current). ONE
  launcher button (`square.grid.2x2.fill`) sits in the Control Strip — one slot
  regardless of how many items exist. Tapping it (`openModal`) presents a
  full-width modal `NSTouchBar` (built via delegate) holding every configured
  item + a trailing ✕ close button. Modal order: **sliders left, buttons right**
  (`modalIdentifiers()`). `.button` → `NSButton` (icon/title, bezelColor) running
  its actions; `.slider` → full-width `NSSliderTouchBarItem` driving NightShift.
  Dismissing the modal clears the launcher from the Control Strip, so
  `closeModal` calls `reassertLauncher()` (re-add + presence) after a 0.1s delay.
- **TouchBarEditor.swift** — SwiftUI editor: type (button/slider), appearance
  (title, SF Symbol OR "Choose Image…", icon size 12–28, custom background
  color), action (button) or slider target.
- **SettingsUI.swift** — three-pane `NavigationSplitView`. Sidebar: Profiles +
  Devices (Touch Bar). `NewProfileSheet` lists running apps with icons + "Browse
  Applications…" (`NSOpenPanel`) — no typing bundle IDs.
- **BindingEditor.swift** — trigger + action editor (trigger kind is a menu
  picker now that there are 6 kinds), fingers picker (2/3/4) for swipes and
  (2–5) for taps, in/out picker for pinch, CW/CCW picker for rotate, permissions
  banner. A **"Record" button** (shown only for non-keyboard trigger kinds, with
  a `.help` tooltip) sets `Engine.shared.gestureRecorder`; the next trackpad
  gesture you perform auto-fills the trigger kind + finger count + direction.
  Recorder is cleared on disappear/cancel. The **Launch App** action uses
  `AppPickerButton` (from **AppPicker.swift**) instead of a text field — a picker
  of running apps + Browse Applications (no typing bundle IDs); it stores the
  bundle id in `Action.argument`, and `Action.summary` resolves it to a friendly
  name ("Launch Safari"). **AppPicker.swift** also has `AppInfo` (bundle id →
  name/icon/url helpers).
- **ConfigStore.swift** — persistence + `activeBindings` (app profile first,
  then global) + add/update/delete Touch Bar items.
- Helpers: **ColorHex.swift** (`NSColor(hex:)`/`hexString`),
  **ShortcutRecorder.swift**, **KeyNames.swift**, **Log.swift**.

## Touch Bar design history (why it's a launcher)

The Control Strip has only ~5 visible slots shared with system buttons
(Siri/sleep/volume/brightness), so **only one custom item reliably renders**.
Placing items directly in the strip → the 2nd item gets dropped (tried it twice;
freeing system slots didn't help). Solution = single launcher → full-width modal
holding all items. This is how BTT itself works and removes the slot limit. The
modal slider gets full width (the old inline slider was crammed to icon width).

## Current state / known good

- 3-finger swipe up/down → volume: **working, locked.**
- Trackpad taps (2–5 finger), pinch in/out, rotate CW/CCW: **added** via
  `Multitouch.handleAdvanced` (alongside the locked swipe path); bindable in the
  editor. Thresholds may need real-device tuning (see constants in
  `Multitouch.swift`).
- Action library: categorized + searchable picker (`ActionPicker`); new actions
  for window management, media keys, mic mute, Mission Control, Control Center,
  lock screen, Run AppleScript. Window-management + lock + Control Center +
  keyboard actions **require Accessibility** — if the installed app shows
  `accessibilityTrusted=false` in the log, grant it in System Settings.
- Touch Bar: launcher shows in Control Strip; tap opens modal with Night Shift
  slider (left) + Capture button (right) + close. Config currently has those 2.
- Night Shift toggle is left to Control Center; we only expose the intensity
  slider.
- Capture (Touch Bar button): **working** — copies the shot to the clipboard
  and saves a PNG to ~/Desktop. Needs Screen Recording permission (auto-prompted
  on first use). Packaged + installable via `./package.sh` (ad-hoc signed `.app`).

## Possible next steps (not yet done)

- Make the launcher icon itself customizable.
- More slider targets (e.g. true brightness, keyboard backlight).
- Reorder Touch Bar items by drag in the editor (currently slider-then-button).
- Old dead project at `/Users/mac/Documents/automation-platform/` (TypeScript)
  can be deleted — superseded by this app.
