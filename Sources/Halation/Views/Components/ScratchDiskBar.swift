import SwiftUI

/// What a render is holding on disk, under the memory chart.
///
/// Two segments in one track — swap first, then the scratch directories —
/// because they are one story: the disk filling up while a render runs. Swap is
/// where the gigabytes actually go; scratch stays in megabytes and is shown
/// beside it so a scratch that ever does grow is visible rather than lost in a
/// figure swap dominates.
///
/// A bar rather than a history, because unlike memory this does not oscillate:
/// it climbs through a render and falls when the render is done. What matters
/// is the level now and how close it is to the edge.
struct ScratchDiskBar: View {
    private static let barHeight: CGFloat = 8
    private static let radius: CGFloat = 4
    /// A segment this short says "some, but hardly any", which is more honest
    /// than one that reads as empty when gigabytes are in fact sitting there.
    private static let minimumSegment: CGFloat = 10

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
                         Format.bytesIncludingZero(gauge.reading.swap),
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
            let widths = segmentWidths(in: proxy.size.width)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.55))
                    .overlay { Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1) }

                HStack(spacing: 0) {
                    if widths.swap > 0 {
                        segment(width: widths.swap,
                                tint: colour(gauge.level.swapTint),
                                roundedLeading: true,
                                roundedTrailing: widths.scratch == 0)
                    }
                    if widths.scratch > 0 {
                        segment(width: widths.scratch,
                                tint: colour(gauge.level.scratchTint),
                                roundedLeading: widths.swap == 0,
                                roundedTrailing: true)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: gauge.reading)
        }
        .frame(height: Self.barHeight)
        .accessibilityElement()
        .accessibilityLabel(loc("scratch.bar.title"))
        .accessibilityValue(percentText)
    }

    /// Square where the two meet and round only at the ends of the track, so
    /// the pair reads as one bar rather than two pills. Leading/trailing, not
    /// left/right, so it mirrors in Arabic for free.
    private func segment(width: CGFloat, tint: Color,
                         roundedLeading: Bool, roundedTrailing: Bool) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: roundedLeading ? Self.radius : 0,
            bottomLeadingRadius: roundedLeading ? Self.radius : 0,
            bottomTrailingRadius: roundedTrailing ? Self.radius : 0,
            topTrailingRadius: roundedTrailing ? Self.radius : 0)
            .fill(
                // A slight gradient down the fill, so at eight points tall it
                // still reads as an object rather than a stripe of flat colour.
                LinearGradient(colors: [tint, tint.opacity(0.72)],
                               startPoint: .top, endPoint: .bottom))
            .frame(width: width)
            .shadow(color: tint.opacity(0.45), radius: 3, y: 0)
    }

    /// Each segment gets a floor so a small one is still visible — but only
    /// when it has something in it. A stub of colour for nothing at all would
    /// claim something is there.
    private func segmentWidths(in width: CGFloat) -> (swap: CGFloat, scratch: CGFloat) {
        let reading = gauge.reading
        var swap = reading.swap > 0
            ? max(Self.minimumSegment, width * reading.swapFraction) : 0
        var scratch = reading.scratch > 0
            ? max(Self.minimumSegment, width * reading.scratchFraction) : 0
        // Those floors can together ask for more than the track has on a very
        // narrow window; give the space back proportionally rather than letting
        // one segment run off the end.
        if swap + scratch > width, swap + scratch > 0 {
            let scale = width / (swap + scratch)
            swap *= scale
            scratch *= scale
        }
        return (swap, scratch)
    }

    private func colour(_ tint: ScratchDiskGauge.Tint) -> Color {
        switch tint {
        // The same violet the memory chart uses for swap: it is the same swap,
        // and two colours for one thing would be a puzzle to solve rather than
        // a reading to take.
        case .violet: Color(red: 0.48, green: 0.38, blue: 0.78)
        case .green: Color(red: 0.37, green: 0.82, blue: 0.23)
        case .orange: Color(red: 0.96, green: 0.62, blue: 0.11)
        case .yellow: Color(red: 0.97, green: 0.84, blue: 0.26)
        case .red: Color(red: 0.93, green: 0.27, blue: 0.24)
        case .pink: Color(red: 0.95, green: 0.45, blue: 0.68)
        }
    }

    /// One decimal below ten percent, none above: 0.3% and 0% are worth telling
    /// apart, 41% and 41.4% are not.
    private var percentText: String {
        let percent = gauge.reading.fraction * 100
        let digits = percent < 10 ? 1 : 0
        return percent.formatted(
            .number.precision(.fractionLength(digits)).locale(Localization.currentLocale)) + "%"
    }
}
