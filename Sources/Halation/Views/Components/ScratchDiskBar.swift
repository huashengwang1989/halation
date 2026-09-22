import SwiftUI

/// How much of the disk the render scratch is holding, under the memory chart.
///
/// A bar rather than a history, because unlike memory this does not oscillate:
/// it climbs through a render and drops when the render clears up. What matters
/// is the level now and whether it is close to the edge.
struct ScratchDiskBar: View {
    private static let barHeight: CGFloat = 8
    /// A fill this short says "some, but hardly any", which is more honest than
    /// a bar that reads as empty when a few gigabytes are in fact sitting there.
    private static let minimumFill: CGFloat = 10

    private var gauge: ScratchDiskGauge { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(loc("scratch.bar.title"))
                    .font(.caption.weight(.medium))
                Spacer()
                Text(loc("scratch.bar.summary",
                         Format.bytesIncludingZero(gauge.reading.scratch),
                         percentText,
                         Format.bytes(gauge.reading.free)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            bar
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .task { gauge.start() }
    }

    private var bar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            // The floor applies to "a little", not to "none": an empty scratch
            // draws an empty bar, because a stub of colour would claim
            // something is there.
            let raw = width * gauge.reading.fraction
            let filled = gauge.reading.scratch > 0
                ? max(Self.minimumFill, min(width, raw))
                : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.55))
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }

                Capsule()
                    .fill(
                        // A slight gradient down the fill, so at eight points
                        // tall it still reads as an object rather than a stripe
                        // of flat colour.
                        LinearGradient(colors: [tint.opacity(1.0), tint.opacity(0.72)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(alignment: .top) {
                        // A one-point highlight along the top edge, inset so it
                        // follows the capsule rather than crossing its ends.
                        Capsule()
                            .fill(.white.opacity(0.28))
                            .frame(height: 1)
                            .padding(.horizontal, 3)
                            .padding(.top, 1)
                    }
                    .frame(width: filled)
                    .shadow(color: tint.opacity(0.45), radius: 3, y: 0)
            }
            .animation(.easeInOut(duration: 0.35), value: gauge.reading)
        }
        .frame(height: Self.barHeight)
        .accessibilityElement()
        .accessibilityLabel(loc("scratch.bar.title"))
        .accessibilityValue(percentText)
    }

    private var tint: Color {
        switch gauge.level.tint {
        case .green: Color(red: 0.37, green: 0.82, blue: 0.23)
        case .orange: Color(red: 0.96, green: 0.62, blue: 0.11)
        case .red: Color(red: 0.93, green: 0.27, blue: 0.24)
        }
    }

    /// One decimal below ten percent, none above: a scratch at 0.3% and one at
    /// 0% are worth telling apart, 41% and 41.4% are not.
    private var percentText: String {
        let percent = gauge.reading.fraction * 100
        let digits = percent < 10 ? 1 : 0
        return percent.formatted(
            .number.precision(.fractionLength(digits)).locale(Localization.currentLocale)) + "%"
    }
}
