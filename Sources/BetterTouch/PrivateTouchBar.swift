import AppKit

/// Bridges the private DFRFoundation framework + private NSTouchBar SPI so we
/// can place persistent custom buttons in the Control Strip (right side of the
/// Touch Bar) — the same mechanism BetterTouchTool / MTMR use.
enum DFR {
    private typealias SetPresenceFn = @convention(c) (CFString, Bool) -> Void
    private typealias ShowCloseBoxFn = @convention(c) (Bool) -> Void

    private static let handle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)

    /// True when the Touch Bar private APIs are available (Touch Bar hardware).
    static var isAvailable: Bool { handle != nil }

    static func setControlStripPresence(_ identifier: String, _ present: Bool) {
        guard let h = handle,
              let sym = dlsym(h, "DFRElementSetControlStripPresenceForIdentifier")
        else { return }
        let fn = unsafeBitCast(sym, to: SetPresenceFn.self)
        fn(identifier as CFString, present)
    }

    static func showsCloseBoxWhenFrontMost(_ shows: Bool) {
        guard let h = handle,
              let sym = dlsym(h, "DFRSystemModalShowsCloseBoxWhenFrontMost")
        else { return }
        let fn = unsafeBitCast(sym, to: ShowCloseBoxFn.self)
        fn(shows)
    }

    /// Calls the private `+[NSTouchBarItem addSystemTrayItem:]`.
    static func addSystemTrayItem(_ item: NSTouchBarItem) {
        let sel = Selector(("addSystemTrayItem:"))
        let cls: AnyObject = NSTouchBarItem.self
        if cls.responds(to: sel) {
            _ = cls.perform(sel, with: item)
        }
    }

    /// Presents a full-width modal Touch Bar anchored to a Control Strip tray
    /// item — `+[NSTouchBar presentSystemModalTouchBar:systemTrayItemIdentifier:]`.
    static func presentSystemModalTouchBar(_ bar: NSTouchBar, trayIdentifier: String) {
        let sel = Selector(("presentSystemModalTouchBar:systemTrayItemIdentifier:"))
        let cls: AnyObject = NSTouchBar.self
        if cls.responds(to: sel) {
            _ = cls.perform(sel, with: bar, with: trayIdentifier as NSString)
        }
    }

    static func dismissSystemModalTouchBar(_ bar: NSTouchBar) {
        let sel = Selector(("dismissSystemModalTouchBar:"))
        let cls: AnyObject = NSTouchBar.self
        if cls.responds(to: sel) {
            _ = cls.perform(sel, with: bar)
        }
    }
}
