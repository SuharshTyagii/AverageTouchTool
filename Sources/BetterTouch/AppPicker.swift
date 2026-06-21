import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Resolves friendly names + icons for an app bundle identifier.
enum AppInfo {
    static func url(forBundleID bid: String) -> URL? {
        guard !bid.isEmpty else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
    }
    /// Clean display name (no ".app"); falls back to the raw value for legacy
    /// configs that stored an app name instead of a bundle id.
    static func name(forBundleID bid: String) -> String? {
        guard !bid.isEmpty else { return nil }
        return url(forBundleID: bid)?.deletingPathExtension().lastPathComponent ?? bid
    }
    static func icon(forBundleID bid: String) -> NSImage? {
        guard let url = url(forBundleID: bid) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// A button that shows the chosen app (icon + name) and opens a picker sheet to
/// choose from running apps or browse /Applications. Stores the app's bundle id.
/// Never makes the user type a bundle id or app name.
struct AppPickerButton: View {
    @Binding var bundleID: String
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 8) {
                if let icon = AppInfo.icon(forBundleID: bundleID) {
                    Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                } else {
                    Image(systemName: "app.dashed").frame(width: 20).foregroundStyle(.secondary)
                }
                Text(AppInfo.name(forBundleID: bundleID) ?? "Choose App…")
                    .foregroundStyle(bundleID.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showing) {
            AppPickerSheet { bid in bundleID = bid }
        }
    }
}

private struct AppRow: Identifiable, Hashable {
    let id: String      // bundle id
    let name: String
    let icon: NSImage?
}

/// Lists running apps with icons (and a Browse fallback) and returns the chosen
/// app's bundle id. Mirrors the New Profile sheet — no typing of identifiers.
private struct AppPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (String) -> Void

    @State private var selection: String?
    @State private var search = ""

    private var runningApps: [AppRow] {
        var seen = Set<String>()
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> AppRow? in
            guard app.activationPolicy == .regular,
                  let bid = app.bundleIdentifier,
                  bid != Bundle.main.bundleIdentifier,
                  !seen.contains(bid) else { return nil }
            seen.insert(bid)
            return AppRow(id: bid, name: app.localizedName ?? bid, icon: app.icon)
        }
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !search.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose an App to Launch").font(.headline)
            Text("Pick a running app, or browse your Applications folder.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("Filter running apps…", text: $search)
                .textFieldStyle(.roundedBorder)

            List(runningApps, selection: $selection) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon {
                        Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "app.dashed").frame(width: 20)
                    }
                    Text(app.name)
                    Spacer()
                }
                .tag(app.id)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture(count: 2).onEnded { choose(app.id) })
            }
            .frame(height: 300)

            HStack {
                Button {
                    browseApplications()
                } label: { Label("Browse Applications…", systemImage: "folder") }

                Spacer()
                Button("Cancel") { dismiss() }
                Button("Choose") {
                    if let bid = selection { choose(bid) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func choose(_ bundleID: String) {
        onPick(bundleID)
        dismiss()
    }

    private func browseApplications() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bundleID = Bundle(url: url)?.bundleIdentifier
            ?? url.deletingPathExtension().lastPathComponent
        choose(bundleID)
    }
}
