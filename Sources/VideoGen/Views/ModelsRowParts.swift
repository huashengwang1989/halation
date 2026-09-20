import SwiftUI

// The small pieces a model row is built from, split out of
// `ModelsCatalogSections.swift` so that file stays about the rows themselves.

struct TagPill: View {
    var text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.16), in: .capsule)
            .foregroundStyle(tint)
    }
}

/// Anything in the folder that is clearly a model but not one we drive. Shown so
/// the folder never looks emptier than it is.
struct UnrecognisedCard: View {
    @Environment(AppState.self) private var app

    private var others: [InstalledModel] {
        app.modelStore.installed.filter { !$0.isKnown }
    }

    var body: some View {
        if !others.isEmpty {
            GlassCard(title: loc("models.other.title"), systemImage: "questionmark.folder",
                      footnote: loc("models.other.footnote")) {
                VStack(spacing: 6) {
                    ForEach(others) { model in
                        HStack {
                            Text(model.repoID).font(.callout).lineLimit(1)
                            TagPill(text: model.layout.label)
                            Spacer()
                            Text(Format.bytes(model.sizeBytes))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}

/// How a row's status reads on screen.
extension EntryRow {
    var statusSymbol: String {
        switch status {
        case .absent:     "circle.dashed"
        case .downloaded: "circle.fill"
        case .inUse:      "checkmark.circle.fill"
        case .missing:    "exclamationmark.triangle.fill"
        }
    }

    var statusTint: AnyShapeStyle {
        switch status {
        case .absent, .downloaded: AnyShapeStyle(.secondary)
        case .inUse:               AnyShapeStyle(.green)
        case .missing:             AnyShapeStyle(.orange)
        }
    }

    var statusLabel: String {
        switch status {
        case .absent:     loc("models.notInstalled")
        case .downloaded: loc("models.installed")
        case .inUse:      loc("models.status.inUse")
        case .missing:    loc("models.status.missing")
        }
    }

}

/// Copies one string, and confirms it did.
///
/// The tick matters more than it looks: a copy button with no feedback leaves you
/// pressing it twice because nothing happened on screen.
struct CopyButton: View {
    let value: String
    let help: String

    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copied = true
        } label: {
            Image(systemName: copied ? "checkmark" : "document.on.document")
                .font(.caption2)
                .foregroundStyle(copied ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
