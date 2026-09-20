import SwiftUI

/// Names a new preset, and refuses a name already in use.
///
/// A sheet rather than an alert. An alert's message is fixed at the moment it is
/// presented — the Save button's enabled state updates live, but the text does
/// not — so the reason a duplicate is refused could never be shown, leaving a dim
/// button and no explanation.
struct PresetNamer: View {
    @Binding var name: String
    /// The names already on the menu, as the menu shows them.
    var taken: [String]
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    /// Leading and trailing space is never what anyone meant, and a name
    /// differing from another only by it would be indistinguishable in the menu.
    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Compared without case, so a difference of capitals cannot produce two
    /// entries that read the same. Compared against the displayed names, so a
    /// built-in's translated name counts too.
    private var isTaken: Bool {
        !trimmed.isEmpty && taken.contains {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    private var canSave: Bool { !trimmed.isEmpty && !isTaken }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc("compose.preset.save.title"))
                .font(.headline)

            Text(loc("compose.preset.save.message"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(loc("common.name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { if canSave { save() } }

            if isTaken {
                Label(loc("compose.preset.duplicate", trimmed),
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(loc("common.cancel")) {
                    name = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(loc("common.save")) { save() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { isFocused = true }
    }

    private func save() {
        onSave(trimmed)
        name = ""
        dismiss()
    }
}
