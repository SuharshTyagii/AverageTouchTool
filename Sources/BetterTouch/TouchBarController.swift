import AppKit

/// BTT-style layout that scales past the Control Strip's ~5-slot limit:
/// a SINGLE launcher button lives in the Control Strip. Tapping it opens a
/// FULL-WIDTH modal Touch Bar containing every configured item — buttons run
/// their actions, sliders get the whole bar width to drag. Add as many items
/// as you like; the Control Strip footprint stays at one slot.
final class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()

    // The single, always-present Control Strip launcher.
    private let launcherIdentifier = "com.bettertouch.tb.launcher"
    private var launcherItem: NSCustomTouchBarItem?

    // Config + per-modal-item lookup.
    private var buttons: [TouchBarButton] = []
    private var itemByIdentifier: [String: TouchBarButton] = [:]
    private var modalBar: NSTouchBar?
    private let dismissIdentifier = "com.bettertouch.tb.dismiss"

    private func identifier(for button: TouchBarButton) -> String {
        "com.bettertouch.tb.item.\(button.id.uuidString)"
    }

    /// Rebuild from config. Only the launcher touches the Control Strip; all
    /// items live in the modal bar, (re)built on demand.
    func rebuild(from buttons: [TouchBarButton]) {
        guard DFR.isAvailable else { Log.line("TB: no Touch Bar"); return }
        self.buttons = buttons
        itemByIdentifier = Dictionary(uniqueKeysWithValues: buttons.map { (identifier(for: $0), $0) })

        installLauncherIfNeeded()

        // If the modal is open, refresh its contents live.
        if let bar = modalBar {
            bar.defaultItemIdentifiers = modalIdentifiers()
        }
        Log.line("TB: rebuilt, \(buttons.count) item(s) behind launcher")
    }

    private func installLauncherIfNeeded() {
        guard launcherItem == nil else { return }
        let item = NSCustomTouchBarItem(identifier: .init(launcherIdentifier))
        let image = NSImage(systemSymbolName: "square.grid.2x2.fill",
                            accessibilityDescription: "AverageTouchTool") ?? NSImage()
        item.view = NSButton(image: image, target: self, action: #selector(openModal))
        launcherItem = item
        DFR.addSystemTrayItem(item)
        DFR.setControlStripPresence(launcherIdentifier, true)
        Log.line("TB: installed launcher")
    }

    // MARK: Modal presentation

    @objc private func openModal() {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = modalIdentifiers()
        modalBar = bar
        DFR.presentSystemModalTouchBar(bar, trayIdentifier: launcherIdentifier)
        Log.line("TB: opened modal with \(buttons.count) item(s)")
    }

    private func modalIdentifiers() -> [NSTouchBarItem.Identifier] {
        // Sliders on the left, buttons on the right (order preserved within each
        // group), then the trailing close button.
        let ordered = buttons.filter { $0.kind == .slider } + buttons.filter { $0.kind != .slider }
        var ids = ordered.map { NSTouchBarItem.Identifier(identifier(for: $0)) }
        ids.append(.init(dismissIdentifier))
        return ids
    }

    @objc private func closeModal() {
        if let bar = modalBar { DFR.dismissSystemModalTouchBar(bar) }
        modalBar = nil
        // Dismissing the modal clears the launcher from the Control Strip, so
        // re-assert it (once the dismiss has settled).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.reassertLauncher()
        }
    }

    private func reassertLauncher() {
        guard let item = launcherItem else { return }
        DFR.addSystemTrayItem(item)
        DFR.setControlStripPresence(launcherIdentifier, true)
        Log.line("TB: re-asserted launcher after modal close")
    }

    // MARK: NSTouchBarDelegate — build each modal item on demand

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier.rawValue == dismissIdentifier {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let img = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
            item.view = NSButton(image: img ?? NSImage(), target: self, action: #selector(closeModal))
            return item
        }

        guard let button = itemByIdentifier[identifier.rawValue] else { return nil }

        switch button.kind {
        case .button:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let control: NSButton
            if let image = icon(for: button) {
                control = NSButton(image: image, target: self, action: #selector(handleTap(_:)))
            } else {
                control = NSButton(title: button.title, target: self, action: #selector(handleTap(_:)))
            }
            control.identifier = NSUserInterfaceItemIdentifier(identifier.rawValue)
            if let color = NSColor(hex: button.backgroundColorHex) { control.bezelColor = color }
            item.view = control
            return item

        case .slider:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.slider.minValue = 0
            item.slider.maxValue = 1
            item.slider.doubleValue = Double(currentValue(for: button.sliderTarget))
            item.label = button.title.isEmpty ? button.sliderTarget.label : button.title
            item.target = self
            item.action = #selector(handleSlider(_:))
            return item
        }
    }

    private func currentValue(for target: SliderTarget) -> Float {
        switch target { case .nightShift: return NightShift.shared.strength() }
    }

    // MARK: Actions

    @objc private func handleTap(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let button = itemByIdentifier[id] else { return }
        let app = NSWorkspace.shared.frontmostApplication?.localizedName
        for action in button.actions { ActionRunner.run(action, frontmostApp: app) }
    }

    @objc private func handleSlider(_ sender: NSSliderTouchBarItem) {
        guard let button = itemByIdentifier[sender.identifier.rawValue] else { return }
        let value = Float(sender.slider.doubleValue)
        switch button.sliderTarget {
        case .nightShift: NightShift.shared.apply(value)
        }
    }

    // MARK: Icon building

    private func icon(for button: TouchBarButton) -> NSImage? {
        let size = max(8, button.iconSize)
        if !button.customIconPath.isEmpty,
           let image = NSImage(contentsOfFile: button.customIconPath) {
            let copy = image.copy() as! NSImage
            copy.size = NSSize(width: size, height: size)
            return copy
        }
        if !button.sfSymbol.isEmpty {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            return NSImage(systemSymbolName: button.sfSymbol, accessibilityDescription: button.title)?
                .withSymbolConfiguration(config)
        }
        return nil
    }
}
