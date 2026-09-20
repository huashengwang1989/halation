import SwiftUI

/// A segmented control whose end segments square off against their track.
///
/// The system style is `.pickerStyle(.segmented)`, and it is what this replaces.
/// On macOS 26 it draws the selection as a fully rounded pill inset inside the
/// track, so the selected option reads as a separate object sitting on top rather
/// than as one of the positions — and SwiftUI exposes no way to change that shape.
/// Hence a small reimplementation: the two ends round to match the track, every
/// edge between them is square, and the whole thing reads as one control with
/// several positions, the way the alignment controls in Pages do.
///
/// The radii are expressed as leading and trailing rather than left and right, so
/// a right-to-left interface mirrors them with no extra code — in Arabic the first
/// option rounds on the right.
struct SegmentedPicker<Value: Hashable, Content: View>: View {
    @Binding var selection: Value
    let options: [Value]
    @ViewBuilder let content: (Value) -> Content

    private let radius: CGFloat = 7

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                segment(option, at: index)
            }
        }
        .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: radius))
        .accessibilityElement(children: .contain)
    }

    private func segment(_ option: Value, at index: Int) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            content(option)
                .font(.callout)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                // The whole segment is the target, not just its text.
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected { shape(at: index).fill(Color.accentColor) }
        }
        .overlay(alignment: .leading) {
            // A hairline only between two unselected neighbours: next to the
            // selection the fill is already the boundary, and drawing both reads
            // as a double rule.
            if index > 0, !isSelected, options[index - 1] != selection {
                Rectangle()
                    .fill(.separator)
                    .frame(width: 1)
                    .padding(.vertical, 5)
            }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Square except where the segment meets the end of the track.
    private func shape(at index: Int) -> UnevenRoundedRectangle {
        let isFirst = index == 0
        let isLast = index == options.count - 1
        return UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? radius : 0,
            bottomLeadingRadius: isFirst ? radius : 0,
            bottomTrailingRadius: isLast ? radius : 0,
            topTrailingRadius: isLast ? radius : 0)
    }
}
