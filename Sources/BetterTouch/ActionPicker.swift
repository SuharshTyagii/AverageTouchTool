import SwiftUI

/// A BTT-style action chooser: a button showing the current action that opens a
/// popover anchored to it. The popover has a search field and collapsible,
/// icon-tagged category sections.
struct ActionPicker: View {
    @Binding var selection: ActionKind
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selection.icon)
                    .frame(width: 18)
                    .foregroundStyle(.tint)
                Text(selection.label)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            ActionPickerList(selection: $selection, dismiss: { showing = false })
        }
    }
}

private struct ActionPickerList: View {
    @Binding var selection: ActionKind
    let dismiss: () -> Void

    @State private var query = ""
    @State private var collapsed: Set<ActionCategory> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search actions", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(ActionCategory.allCases) { cat in
                        let items = actions(in: cat)
                        if !items.isEmpty {
                            section(cat, items)
                        }
                    }
                    if ActionCategory.allCases.allSatisfy({ actions(in: $0).isEmpty }) {
                        Text("No actions match “\(query)”")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                .padding(6)
            }
        }
        .frame(width: 330, height: 400)
    }

    private func actions(in cat: ActionCategory) -> [ActionKind] {
        ActionKind.allCases.filter {
            $0.category == cat &&
            (query.isEmpty || $0.label.localizedCaseInsensitiveContains(query))
        }
    }

    /// While searching, force every matching section open.
    private func isExpanded(_ cat: ActionCategory) -> Bool {
        query.isEmpty ? !collapsed.contains(cat) : true
    }

    @ViewBuilder
    private func section(_ cat: ActionCategory, _ items: [ActionKind]) -> some View {
        let expanded = isExpanded(cat)
        Button {
            if collapsed.contains(cat) { collapsed.remove(cat) } else { collapsed.insert(cat) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .frame(width: 16).foregroundStyle(.secondary)
                Text(cat.rawValue)
                    .font(.caption).bold().foregroundStyle(.secondary)
                Spacer()
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5).padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .disabled(!query.isEmpty)

        if expanded {
            ForEach(items) { kind in
                Button {
                    selection = kind
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: kind.icon)
                            .frame(width: 20)
                            .foregroundStyle(.tint)
                        Text(kind.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if kind == selection {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(
                        kind == selection ? Color.accentColor.opacity(0.14) : .clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
