import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct AverageTouchToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ConfigStore.shared
    @StateObject private var engine = Engine.shared

    var body: some Scene {
        MenuBarExtra("AverageTouchTool", systemImage: "hand.point.up.left.and.text") {
            MenuContent()
                .environmentObject(store)
                .environmentObject(engine)
        }

        Window("AverageTouchTool", id: "settings") {
            SettingsView()
                .environmentObject(store)
                .environmentObject(engine)
                .frame(minWidth: 860, minHeight: 540)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent: no Dock icon.
        NSApp.setActivationPolicy(.accessory)
        // Ask for Accessibility/Input Monitoring up front, then start capturing.
        _ = Permissions.isTrusted(prompt: true)
        Engine.shared.start()
    }
}

/// The dropdown shown from the menu-bar icon.
struct MenuContent: View {
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var engine: Engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let name = engine.frontmostName {
            Text("Frontmost: \(name)").font(.caption)
            Divider()
        }

        Toggle("Enabled", isOn: $store.globallyEnabled)

        if !engine.keyboardTapActive {
            Button("⚠️ Grant Input Monitoring…") {
                Permissions.openInputMonitoringSettings()
            }
            Button("Retry keyboard capture") { engine.retryKeyboardTap() }
            Divider()
        }

        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()
        Button("Export Bindings…") { exportBindings() }
        Button("Import Bindings…") { importBindings() }

        Divider()
        Button("Quit AverageTouchTool") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: Import / export

    private func exportBindings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "AverageTouchTool-bindings.json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let data = store.exportJSON() else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func importBindings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        let alert = NSAlert()
        alert.messageText = "Replace all bindings?"
        alert.informativeText = "Importing will replace your current profiles, bindings, and Touch Bar items with the contents of this file."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if !store.importJSON(data) {
            let err = NSAlert()
            err.messageText = "Import failed"
            err.informativeText = "That file isn't a valid AverageTouchTool export."
            err.runModal()
        }
    }
}
