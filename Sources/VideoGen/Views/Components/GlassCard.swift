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
                    if let systemImage { Image(systemName: systemImage) }
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
struct SpecRow: View {
    var label: String
    var value: String
    var isProminent = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(isProminent ? .primary : .secondary)
                .fontWeight(isProminent ? .semibold : .regular)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
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
        .font(.caption)
        .foregroundStyle(problem.severity == .blocking ? .red : .secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
