import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Customize the Control Strip: add/edit/remove custom Touch Bar buttons & sliders.
struct TouchBarEditor: View {
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var engine: Engine
    @State private var editing: TouchBarButton?
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !engine.touchBarAvailable {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("No Touch Bar detected on this Mac.")
                }
                .padding(10).background(.orange.opacity(0.12))
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Touch Bar").font(.title2).bold()
                    Text("Custom buttons & sliders appear in the Control Strip (right side of the Touch Bar).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingAdd = true } label: { Label("Add Item", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if store.config.touchBarItems.isEmpty {
                ContentUnavailableView("No Touch Bar items",
                                       systemImage: "rectangle.bottomthird.inset.filled",
                                       description: Text("Add a button or a Night Shift slider."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.config.touchBarItems) { button in
                        TouchBarRow(button: button)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = button }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAdd) { TouchBarButtonEditor(existing: nil) }
        .sheet(item: $editing) { b in TouchBarButtonEditor(existing: b) }
    }
}

private struct TouchBarRow: View {
    @EnvironmentObject var store: ConfigStore
    let button: TouchBarButton

    var body: some View {
        HStack(spacing: 12) {
            iconView.frame(width: 24, height: 24)
            Text(button.title).bold().frame(width: 130, alignment: .leading)
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Text(description).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            if !button.backgroundColorHex.isEmpty {
                Circle().fill(Color(nsColor: NSColor(hex: button.backgroundColorHex) ?? .clear))
                    .frame(width: 12, height: 12)
            }
            Button(role: .destructive) {
                store.deleteTouchBarButton(button.id)
            } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var description: String {
        button.kind == .slider
            ? "Slider · \(button.sliderTarget.label)"
            : button.actions.map(\.summary).joined(separator: ", ")
    }

    @ViewBuilder private var iconView: some View {
        if !button.customIconPath.isEmpty, let img = NSImage(contentsOfFile: button.customIconPath) {
            Image(nsImage: img).resizable().scaledToFit()
        } else if !button.sfSymbol.isEmpty {
            Image(systemName: button.sfSymbol).resizable().scaledToFit()
        } else {
            Image(systemName: button.kind == .slider ? "slider.horizontal.3" : "character.cursor.ibeam")
                .resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }
}

struct TouchBarButtonEditor: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.dismiss) private var dismiss
    let existing: TouchBarButton?

    @State private var kind: TouchBarItemKind = .button
    @State private var title = "Button"
    @State private var sfSymbol = ""
    @State private var customIconPath = ""
    @State private var iconSize: Double = 18
    @State private var useCustomBG = false
    @State private var bgColor = Color.accentColor
    @State private var sliderTarget: SliderTarget = .nightShift

    @State private var actionKind: ActionKind = .runShell
    @State private var argument = ""
    @State private var actionKeyCode: Int?
    @State private var actionMods = Modifiers()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Touch Bar Item" : "Edit Touch Bar Item")
                .font(.title3).bold()

            Picker("Type", selection: $kind) {
                ForEach(TouchBarItemKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            appearanceBox

            if kind == .button {
                actionBox
            } else {
                GroupBox("Slider") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Controls", selection: $sliderTarget) {
                            ForEach(SliderTarget.allCases) { Text($0.label).tag($0) }
                        }
                        Text("Tap the item in the Control Strip to reveal the slider, then drag to set the intensity.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(6)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear(perform: load)
    }

    // MARK: Appearance

    private var appearanceBox: some View {
        GroupBox("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    iconPreview
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Title / label", text: $title).textFieldStyle(.roundedBorder)
                        HStack {
                            TextField("SF Symbol (e.g. moon.fill)", text: $sfSymbol)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!customIconPath.isEmpty)
                            Button("Choose Image…") { chooseIcon() }
                            if !customIconPath.isEmpty {
                                Button("Clear") { customIconPath = "" }
                            }
                        }
                    }
                }

                HStack {
                    Text("Icon size")
                    Slider(value: $iconSize, in: 12...28, step: 1)
                    Text("\(Int(iconSize)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                }

                HStack {
                    Toggle("Custom background", isOn: $useCustomBG)
                    if useCustomBG {
                        ColorPicker("", selection: $bgColor, supportsOpacity: false).labelsHidden()
                    }
                    Spacer()
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder private var iconPreview: some View {
        if !customIconPath.isEmpty, let img = NSImage(contentsOfFile: customIconPath) {
            Image(nsImage: img).resizable().scaledToFit().padding(4)
        } else if !sfSymbol.isEmpty,
                  NSImage(systemSymbolName: sfSymbol, accessibilityDescription: nil) != nil {
            Image(systemName: sfSymbol).resizable().scaledToFit().padding(8)
        } else {
            Image(systemName: "questionmark.square.dashed").resizable().scaledToFit()
                .padding(8).foregroundStyle(.secondary)
        }
    }

    // MARK: Action (button only)

    private var actionBox: some View {
        GroupBox("Action") {
            VStack(alignment: .leading, spacing: 10) {
                ActionPicker(selection: $actionKind)
                if let label = actionKind.argumentLabel {
                    TextField(label, text: $argument).textFieldStyle(.roundedBorder)
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
    }

    // MARK: Load / save

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { customIconPath = url.path }
    }

    private func load() {
        guard let b = existing else { return }
        kind = b.kind
        title = b.title
        sfSymbol = b.sfSymbol
        customIconPath = b.customIconPath
        iconSize = b.iconSize
        sliderTarget = b.sliderTarget
        if !b.backgroundColorHex.isEmpty, let c = NSColor(hex: b.backgroundColorHex) {
            useCustomBG = true
            bgColor = Color(nsColor: c)
        }
        if let a = b.actions.first {
            actionKind = a.kind
            argument = a.argument
            actionKeyCode = a.keyCode
            actionMods = a.modifiers
        }
    }

    private func save() {
        var button = existing ?? TouchBarButton()
        button.kind = kind
        button.title = title
        button.sfSymbol = sfSymbol
        button.customIconPath = customIconPath
        button.iconSize = iconSize
        button.backgroundColorHex = useCustomBG ? NSColor(bgColor).hexString : ""
        button.sliderTarget = sliderTarget

        if kind == .button {
            var action = Action(kind: actionKind, argument: argument)
            if actionKind.usesKeyCombo {
                action.keyCode = actionKeyCode
                action.modifiers = actionMods
            }
            button.actions = [action]
        } else {
            button.actions = []
        }

        if existing == nil {
            store.addTouchBarButton(button)
        } else {
            store.updateTouchBarButton(button)
        }
        dismiss()
    }
}
