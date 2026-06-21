import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case profile(UUID)
    case touchBar
}

struct SettingsView: View {
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var engine: Engine
    @State private var selection: SidebarItem?
    @State private var showingNewProfile = false

    private var current: SidebarItem {
        selection ?? store.config.profiles.first.map { .profile($0.id) } ?? .touchBar
    }

    /// The real Finder icon for an app profile, resolved from its bundle id.
    private func appIcon(for bundleID: String?) -> NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Profiles") {
                    ForEach(store.config.profiles) { profile in
                        Label {
                            Text(profile.name)
                        } icon: {
                            if profile.isGlobal {
                                Image(systemName: "globe")
                            } else if let icon = appIcon(for: profile.bundleID) {
                                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "app.dashed")
                            }
                        }
                        .tag(SidebarItem.profile(profile.id))
                        .contextMenu {
                            if !profile.isGlobal {
                                Button("Delete Profile", role: .destructive) {
                                    store.deleteProfile(profile.id)
                                }
                            }
                        }
                    }
                }
                Section("Devices") {
                    Label("Touch Bar", systemImage: "rectangle.bottomthird.inset.filled")
                        .tag(SidebarItem.touchBar)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingNewProfile = true
                } label: {
                    Label("Add App Profile", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
        } detail: {
            switch current {
            case .touchBar:
                TouchBarEditor()
            case .profile(let pid):
                if let idx = store.config.profiles.firstIndex(where: { $0.id == pid }) {
                    ProfileDetail(profileID: pid, profileIndex: idx)
                } else {
                    ContentUnavailableView("No Profile", systemImage: "square.dashed")
                }
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            NewProfileSheet()
        }
        .onAppear {
            // The detail pane defaults to the first profile (Global); mirror that
            // in the sidebar so it actually shows as selected.
            if selection == nil {
                selection = store.config.profiles.first.map { .profile($0.id) } ?? .touchBar
            }
        }
    }
}

// MARK: - Profile detail (bindings list)

struct ProfileDetail: View {
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var engine: Engine
    let profileID: UUID
    let profileIndex: Int

    @State private var showingAdd = false
    @State private var editing: TriggerBinding?

    private var profile: Profile { store.config.profiles[profileIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PermissionsBanner()

            HStack {
                VStack(alignment: .leading) {
                    Text(profile.name).font(.title2).bold()
                    Text(profile.isGlobal
                         ? "Active everywhere"
                         : "Active when \(profile.bundleID ?? "?") is frontmost")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()

                let otherProfiles = store.config.profiles.filter {
                    $0.id != profileID && !$0.bindings.isEmpty
                }
                if !otherProfiles.isEmpty {
                    Menu {
                        ForEach(otherProfiles) { src in
                            Button("\(src.name) (\(src.bindings.count))") {
                                store.copyAllBindings(from: src.id, to: profileID)
                            }
                        }
                    } label: {
                        Label("Copy From", systemImage: "square.on.square")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Copy all bindings from another profile into this one")
                }

                Button {
                    showingAdd = true
                } label: { Label("Add Binding", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if profile.bindings.isEmpty {
                ContentUnavailableView("No bindings yet",
                                       systemImage: "bolt.horizontal",
                                       description: Text("Add a trigger and bind it to actions."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(profile.bindings) { binding in
                        BindingRow(binding: binding, profileID: profileID)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = binding }
                            .contextMenu {
                                let dests = store.config.profiles.filter { $0.id != profileID }
                                if !dests.isEmpty {
                                    Menu("Copy to") {
                                        ForEach(dests) { dest in
                                            Button(dest.name) {
                                                store.copyBinding(binding, toProfile: dest.id)
                                            }
                                        }
                                    }
                                }
                                Button("Delete", role: .destructive) {
                                    store.deleteBinding(binding.id, fromProfile: profileID)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAdd) {
            BindingEditor(profileID: profileID, existing: nil)
        }
        .sheet(item: $editing) { b in
            BindingEditor(profileID: profileID, existing: b)
        }
    }
}

struct BindingRow: View {
    @EnvironmentObject var store: ConfigStore
    let binding: TriggerBinding
    let profileID: UUID

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(.secondary)

                Text(binding.trigger.summary)
                    .frame(width: 150, alignment: .leading)
                    .font(.body.monospaced())
                    .strikethrough(!binding.enabled)

                Image(systemName: "arrow.right").foregroundStyle(.tertiary)

                Text(binding.actions.map(\.summary).joined(separator: ", "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .strikethrough(!binding.enabled)
            }
            .opacity(binding.enabled ? 1 : 0.4)

            Spacer()

            Button {
                var b = binding; b.enabled.toggle()
                store.updateBinding(b, inProfile: profileID)
            } label: {
                Image(systemName: binding.enabled ? "pause.circle" : "play.circle")
            }
            .buttonStyle(.borderless)
            .help(binding.enabled ? "Disable this binding" : "Enable this binding")

            Button(role: .destructive) {
                store.deleteBinding(binding.id, fromProfile: profileID)
            } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch binding.trigger.kind {
        case .keyboardShortcut: return "keyboard"
        case .swipe: return "hand.draw"
        case .tap: return "hand.point.up.left"
        case .pinch: return "arrow.down.right.and.arrow.up.left"
        case .rotate: return "arrow.clockwise"
        }
    }
}

// MARK: - New profile sheet

private struct AppChoice: Identifiable, Hashable {
    let id: String      // bundle id
    let name: String
    let icon: NSImage?
}

struct NewProfileSheet: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: String?
    @State private var search = ""

    /// Visible, regular running apps (deduped by bundle id), minus ourselves.
    private var runningApps: [AppChoice] {
        var seen = Set<String>()
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> AppChoice? in
            guard app.activationPolicy == .regular,
                  let bid = app.bundleIdentifier,
                  bid != Bundle.main.bundleIdentifier,
                  !seen.contains(bid) else { return nil }
            seen.insert(bid)
            return AppChoice(id: bid, name: app.localizedName ?? bid, icon: app.icon)
        }
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !search.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add App Profile").font(.headline)
            Text("Pick a running app, or browse your Applications folder. No typing needed.")
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
                    Text(app.id).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
                .tag(app.id)
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    add(bundleID: app.id, name: app.name)
                })
            }
            .frame(height: 300)

            HStack {
                Button {
                    browseApplications()
                } label: { Label("Browse Applications…", systemImage: "folder") }

                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    if let bid = selection,
                       let app = runningApps.first(where: { $0.id == bid }) {
                        add(bundleID: bid, name: app.name)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func add(bundleID: String, name: String) {
        store.addProfile(name: name, bundleID: bundleID)
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
        let name = url.deletingPathExtension().lastPathComponent
        let bundleID = Bundle(url: url)?.bundleIdentifier ?? name
        add(bundleID: bundleID, name: name)
    }
}
