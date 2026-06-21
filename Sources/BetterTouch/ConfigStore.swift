import Foundation
import Combine

/// Owns the config document, persists it to disk, and exposes binding lookup.
/// ObservableObject so the SwiftUI settings window stays in sync.
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: Config
    @Published var globallyEnabled = true

    private let fileURL: URL

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BetterTouch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(Config.self, from: data) {
            config = loaded
        } else {
            config = .starter
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    var configPath: String { fileURL.path }

    // MARK: Import / export

    /// The whole config (profiles + bindings + Touch Bar items) as pretty JSON.
    func exportJSON() -> Data? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(config)
    }

    /// Replace the current config with a previously exported JSON document.
    /// Returns false if the data isn't a valid config.
    @discardableResult
    func importJSON(_ data: Data) -> Bool {
        guard let loaded = try? JSONDecoder().decode(Config.self, from: data) else { return false }
        config = loaded
        save()
        return true
    }

    // MARK: Profile / binding mutations (always persist)

    func addProfile(name: String, bundleID: String?) {
        config.profiles.append(Profile(name: name, bundleID: bundleID))
        save()
    }

    func deleteProfile(_ id: UUID) {
        config.profiles.removeAll { $0.id == id && !$0.isGlobal }
        save()
    }

    func addBinding(_ binding: TriggerBinding, toProfile profileID: UUID) {
        guard let i = config.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        config.profiles[i].bindings.append(binding)
        save()
    }

    func updateBinding(_ binding: TriggerBinding, inProfile profileID: UUID) {
        guard let pi = config.profiles.firstIndex(where: { $0.id == profileID }),
              let bi = config.profiles[pi].bindings.firstIndex(where: { $0.id == binding.id })
        else { return }
        config.profiles[pi].bindings[bi] = binding
        save()
    }

    func deleteBinding(_ bindingID: UUID, fromProfile profileID: UUID) {
        guard let pi = config.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        config.profiles[pi].bindings.removeAll { $0.id == bindingID }
        save()
    }

    /// Returns a copy of a binding with fresh IDs, so it lives independently of
    /// the original (editing/deleting one won't touch the other).
    private func duplicated(_ binding: TriggerBinding) -> TriggerBinding {
        var copy = binding
        copy.id = UUID()
        copy.actions = binding.actions.map { var a = $0; a.id = UUID(); return a }
        return copy
    }

    /// Copy one binding into another profile (as an independent duplicate).
    func copyBinding(_ binding: TriggerBinding, toProfile profileID: UUID) {
        guard let pi = config.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        config.profiles[pi].bindings.append(duplicated(binding))
        save()
    }

    /// Copy every binding from one profile into another (independent duplicates).
    func copyAllBindings(from sourceID: UUID, to destID: UUID) {
        guard sourceID != destID,
              let si = config.profiles.firstIndex(where: { $0.id == sourceID }),
              let di = config.profiles.firstIndex(where: { $0.id == destID }) else { return }
        let copies = config.profiles[si].bindings.map(duplicated)
        config.profiles[di].bindings.append(contentsOf: copies)
        save()
    }

    // MARK: Touch Bar buttons

    func addTouchBarButton(_ button: TouchBarButton) {
        config.touchBarItems.append(button)
        save()
    }

    func updateTouchBarButton(_ button: TouchBarButton) {
        guard let i = config.touchBarItems.firstIndex(where: { $0.id == button.id }) else { return }
        config.touchBarItems[i] = button
        save()
    }

    func deleteTouchBarButton(_ id: UUID) {
        config.touchBarItems.removeAll { $0.id == id }
        save()
    }

    // MARK: Resolution

    /// Bindings active for the frontmost app, app-specific first (higher priority).
    func activeBindings(frontmostBundleID: String?) -> [TriggerBinding] {
        var result: [TriggerBinding] = []
        if let bundle = frontmostBundleID {
            for p in config.profiles where p.bundleID == bundle {
                result.append(contentsOf: p.bindings)
            }
        }
        for p in config.profiles where p.isGlobal {
            result.append(contentsOf: p.bindings)
        }
        return result
    }
}
