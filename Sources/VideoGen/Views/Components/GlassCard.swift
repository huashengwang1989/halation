import SwiftUI

/// A titled, glass-backed group. Used instead of bare `GroupBox` so panels read as
/// one material family across the window.
struct GlassCard<Content: View>: View {
    var title: String?
    var systemImage: String?
    var footnote: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label {
                    Text(title)
                        .font(.headline)
                } icon: {
                    if let systemImage {
                        Image(systemName: systemImage).accessibilityHidden(true)
                    }
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.primary)
            }

            content

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

/// A short label/value row, right-aligned value, for spec summaries.
///
/// Set `isCopyable` for values worth pasting elsewhere — a seed, mainly, which is
/// the one field you need verbatim to reproduce a render in another tool.
struct SpecRow: View {
    var label: String
    var value: String
    var isProminent = false
    var isCopyable = false

    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            valueText
            if isCopyable { copyButton }
        }
        .font(.callout)
    }

    @ViewBuilder
    private var valueText: some View {
        let text = Text(value)
            .foregroundStyle(isProminent ? .primary : .secondary)
            .fontWeight(isProminent ? .semibold : .regular)
            .multilineTextAlignment(.trailing)

        // Selectable as well as copyable — a partial selection is occasionally
        // what someone wants. The two selectability types differ, so this is a
        // branch rather than a ternary.
        if isCopyable {
            text.textSelection(.enabled)
        } else {
            text
        }
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            withAnimation(.easeOut(duration: 0.15)) { didCopy = true }
            // Revert the confirmation rather than leaving a tick sitting there.
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeIn(duration: 0.25)) { didCopy = false }
            }
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .imageScale(.small)
                .foregroundStyle(didCopy ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 14)
        }
        .buttonStyle(.borderless)
        .help("Copy \(label.lowercased())")
        .accessibilityLabel("Copy \(label.lowercased())")
        .accessibilityValue(didCopy ? "Copied" : value)
    }
}

/// Inline advisory or blocking message.
struct ProblemBadge: View {
    var problem: GenerationSpec.Problem

    var body: some View {
        Label {
            Text(problem.message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: problem.severity == .blocking
                  ? "exclamationmark.octagon.fill" : "info.circle.fill")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(problem.severity == .blocking
                            ? "Blocking issue. \(problem.message)"
                            : "Note. \(problem.message)")
        .font(.caption)
        .foregroundStyle(problem.severity == .blocking ? .red : .secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
