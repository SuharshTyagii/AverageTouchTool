import SwiftUI
import AppKit

/// Records a real keystroke: click "Record", press a combo, and it captures the
/// virtual key code + modifiers via a local NSEvent monitor.
struct ShortcutRecorder: View {
    @Binding var keyCode: Int?
    @Binding var modifiers: Modifiers

    @State private var recording = false

    var body: some View {
        HStack(spacing: 10) {
            Text(display)
                .font(.title3.monospaced())
                .frame(minWidth: 120, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))

            Button(recording ? "Press keys…" : "Record") { toggle() }
                .buttonStyle(.bordered)

            if keyCode != nil {
                Button("Clear") { keyCode = nil; modifiers = Modifiers() }
                    .buttonStyle(.borderless)
            }
        }
        .onDisappear(perform: stop)
    }

    private var display: String {
        guard let code = keyCode else { return recording ? "…" : "—" }
        return modifiers.symbols + KeyNames.name(for: CGKeyCode(code))
    }

    private func toggle() {
        if recording { stop() } else { start() }
    }

    private func start() {
        recording = true
        // Record via the running global tap (Engine) rather than a local
        // NSEvent monitor: combos like ⌃← / ⌃→ are stolen by macOS (Mission
        // Control spaces) before a local monitor ever sees them, but the global
        // tap captures them. Engine swallows the keystroke while recording.
        Engine.shared.keyRecorder = { event in
            // Ignore a bare Escape so it can cancel instead of binding.
            if event.keyCode == 53 && event.modifiers.isEmpty {
                stop(); return
            }
            keyCode = Int(event.keyCode)
            modifiers = event.modifiers
            stop()
        }
    }

    private func stop() {
        recording = false
        Engine.shared.keyRecorder = nil
    }
}
