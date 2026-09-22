import SwiftUI

/// A live mosaic of where the machine's memory is going, pinned above the queue.
///
/// One column of squares per second, entering at the trailing edge and marching
/// off the leading one, in the spirit of Activity Monitor's little history
/// graphs. The window it shows is however many columns fit, so a wider window is
/// simply a longer memory.
struct MemoryChartRow: View {
    @Environment(\.layoutDirection) private var layout

    private var sampler: MemoryChartSampler { .shared }

    /// Square, and the gap after it. A 4 pt pitch puts roughly five minutes on a
    /// full-width window and still gives the vertical scale enough rows to be
    /// worth reading — see `rowCounts(for:)`.
    private let pitch: CGFloat = 4
    private let square: CGFloat = 3

    /// How much of the height is installed memory. The rest is swap, drawn at
    /// the *same* bytes per row, so the two bands share one linear scale and the
    /// rule between them falls exactly at the installed figure. On a 128 GB Mac
    /// that gives the swap band about 43 GB, which is more than macOS has ever
    /// been observed to allocate here.
    private let memoryShare: CGFloat = 0.75

    private let chartHeight: CGFloat = 140

    private var installed: Int64 { MachineProfile.physicalBytes }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                gutter
                chart
            }
            legend
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .task { sampler.start() }
    }

    // MARK: - Pieces

    /// Names the two bands, outside the plot so nothing ever sits under the
    /// data. Aligned to the rule rather than centred: the labels describe the
    /// boundary, not the areas.
    private var gutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(loc("memory.chart.swap"))
                .frame(height: chartHeight * (1 - memoryShare), alignment: .bottom)
            Text(Format.memory(installed))
                .frame(height: chartHeight * memoryShare, alignment: .top)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .frame(width: 56, alignment: .trailing)
    }

    private var chart: some View {
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            draw(in: &context, size: size)
        }
        .frame(height: chartHeight)
        .frame(maxWidth: .infinity)
        // Black in both appearances, as specified — the colours are chosen
        // against black and wash out on a light panel.
        .background(.black)
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)
            ForEach(Band.legendOrder, id: \.self) { band in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(band.color)
                        .frame(width: 8, height: 8)
                    Text(band.label)
                }
            }
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let rows = max(2, Int(size.height / pitch))
        let memoryRows = max(1, Int((CGFloat(rows) * memoryShare).rounded()))
        let swapRows = max(1, rows - memoryRows)
        let bytesPerRow = Double(max(installed, 1)) / Double(memoryRows)
        let columns = max(1, Int(size.width / pitch))

        // The rule at installed memory: everything above it is swap.
        let ruleY = size.height - CGFloat(memoryRows) * pitch
        context.fill(Path(CGRect(x: 0, y: ruleY, width: size.width, height: 1)),
                     with: .color(.white.opacity(0.35)))

        let visible = sampler.history.suffix(columns)
        let leading = columns - visible.count

        for (offset, sample) in visible.enumerated() {
            let column = leading + offset
            let x = xPosition(forColumn: column, columns: columns, width: size.width)

            // Bottom upwards, so the engine sits on the floor and the thin
            // graphics band rides on top where it stays readable.
            var filled = 0
            for (band, count) in rowCounts(for: sample,
                                           rows: memoryRows, bytesPerRow: bytesPerRow) {
                guard count > 0 else { continue }
                for row in filled..<min(memoryRows, filled + count) {
                    paint(&context, x: x, row: row, height: size.height, color: band.color)
                }
                filled += count
            }

            // Swap continues the same scale in the band above the rule.
            let swapRows2 = rowsFor(bytes: sample.swap, bytesPerRow: bytesPerRow, cap: swapRows)
            guard swapRows2 > 0 else { continue }
            for row in memoryRows..<(memoryRows + swapRows2) {
                paint(&context, x: x, row: row, height: size.height, color: Band.swap.color)
            }
        }
    }

    /// How many rows each band gets, floor upwards.
    ///
    /// Cumulative rounding keeps the stack's total height honest — the bands
    /// cannot drift apart from the sum they represent. On top of that, **any
    /// band with bytes in it gets at least one row**, borrowed from the tallest
    /// band.
    ///
    /// That last rule is a deliberate distortion, and worth stating: at 128 GB
    /// over 26 rows a row is about 5 GB, while this app's own footprint is well
    /// under 1 GB and the graphics driver holds around 2 GB. Rounded honestly
    /// both vanish, and two entries in the legend would then never once appear
    /// on the chart. A single row therefore means "some, but less than a row's
    /// worth", not a measurement — the exact figures belong in the status bar,
    /// which has the space to print them.
    private func rowCounts(for sample: MemorySample,
                           rows: Int, bytesPerRow: Double) -> [(Band, Int)] {
        var counts: [(Band, Int)] = []
        var filled = 0
        var cumulative = 0.0
        for band in Band.stackOrder {
            cumulative += Double(sample[band])
            let target = min(rows, Int((cumulative / bytesPerRow).rounded()))
            counts.append((band, max(0, target - filled)))
            filled = max(filled, target)
        }

        // Lift every non-empty band to one row, paying for it out of the tallest.
        for index in counts.indices where counts[index].1 == 0 && sample[counts[index].0] > 0 {
            guard let donor = counts.indices.max(by: { counts[$0].1 < counts[$1].1 }),
                  counts[donor].1 > 1 else { continue }
            counts[donor].1 -= 1
            counts[index].1 = 1
        }
        return counts
    }

    /// One band on its own, with the same "non-zero shows something" floor.
    private func rowsFor(bytes: Int64, bytesPerRow: Double, cap: Int) -> Int {
        guard bytes > 0 else { return 0 }
        return min(cap, max(1, Int((Double(bytes) / bytesPerRow).rounded())))
    }

    /// Newest column at the trailing edge — the right in English, the left in
    /// Arabic — with history marching towards the leading edge.
    private func xPosition(forColumn column: Int, columns: Int, width: CGFloat) -> CGFloat {
        let fromLeading = CGFloat(column) * pitch
        return layout == .rightToLeft ? width - fromLeading - square : fromLeading
    }

    private func paint(_ context: inout GraphicsContext,
                       x: CGFloat, row: Int, height: CGFloat, color: Color) {
        let y = height - CGFloat(row + 1) * pitch
        context.fill(Path(CGRect(x: x, y: y, width: square, height: square)),
                     with: .color(color))
    }
}

// MARK: - Bands

/// The stacked categories, and the one colour table they all read from.
private enum Band: Hashable {
    case engine, app, systemAndOthers, graphics, swap

    /// Floor upwards. Reversed, this is the order the legend and the eye read
    /// the column from the top: graphics, system, app, engine.
    static let stackOrder: [Band] = [.engine, .app, .systemAndOthers, .graphics]
    static let legendOrder: [Band] = [.systemAndOthers, .graphics, .engine, .app, .swap]

    var color: Color {
        switch self {
        case .engine:          Color(red: 0.37, green: 0.82, blue: 0.23)
        case .app:             Color(red: 0.94, green: 0.64, blue: 0.16)
        case .systemAndOthers: Color(red: 0.49, green: 0.49, blue: 0.51)
        case .graphics:        Color(red: 0.64, green: 0.09, blue: 0.37)
        case .swap:            Color(red: 0.48, green: 0.38, blue: 0.78)
        }
    }

    var label: String {
        switch self {
        case .engine:          loc("memory.chart.engine")
        case .app:             loc("memory.chart.app")
        case .systemAndOthers: loc("memory.chart.system")
        case .graphics:        loc("memory.chart.graphics")
        case .swap:            loc("memory.chart.swap")
        }
    }
}

private extension MemorySample {
    subscript(band: Band) -> Int64 {
        switch band {
        case .engine:          engine
        case .app:             app
        case .systemAndOthers: systemAndOthers
        case .graphics:        graphics
        case .swap:            swap
        }
    }
}
