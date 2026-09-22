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
                    RoundedRectangle(cornerRadius: band.isLine ? 1 : 2)
                        .fill(band.color)
                        .frame(width: band.isLine ? 12 : 8, height: band.isLine ? 2 : 8)
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
        var compressedTrace = Path()

        for (offset, sample) in visible.enumerated() {
            let column = leading + offset
            let x = xPosition(forColumn: column, columns: columns, width: size.width)

            // Bottom upwards: the engine's Metal pool on the floor, then the
            // rest of the engine, then this app, then everything else.
            var filled = 0
            for (band, count) in rowCounts(for: sample,
                                           rows: memoryRows, bytesPerRow: bytesPerRow) {
                guard count > 0 else { continue }
                for row in filled..<min(memoryRows, filled + count) {
                    paint(&context, x: x, row: row, height: size.height, color: band.color)
                }
                filled += count
            }

            // Where compression has got to, on the same scale, measured from the
            // floor. Collected now and stroked once at the end so the line sits
            // over every square rather than being interrupted by later columns.
            let compressedY = max(ruleY,
                                  size.height - CGFloat(Double(sample.compressed) / bytesPerRow) * pitch)
            let point = CGPoint(x: x + square / 2, y: compressedY)
            if compressedTrace.isEmpty {
                compressedTrace.move(to: point)
            } else {
                compressedTrace.addLine(to: point)
            }

            // Swap continues the same scale in the band above the rule.
            let swapRows2 = rowsFor(bytes: sample.swap, bytesPerRow: bytesPerRow, cap: swapRows)
            guard swapRows2 > 0 else { continue }
            for row in memoryRows..<(memoryRows + swapRows2) {
                paint(&context, x: x, row: row, height: size.height, color: Band.swap.color)
            }
        }

        // A line, not a band: compression is a state the memory in the bands is
        // already in, so stacking it beside them would count the same pages
        // twice. It also rises before any swap appears, which is the point of
        // showing it — it is the earlier of the two warnings.
        if !compressedTrace.isEmpty {
            context.stroke(compressedTrace, with: .color(Band.compressed.color),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }

    /// How many rows each band gets, floor upwards.
    ///
    /// Plain cumulative rounding, and nothing else: a row is about 5 GB, so a
    /// band under half a row does not light one, and a band over half a row
    /// does. Small categories are therefore simply absent rather than
    /// exaggerated — every square on the chart is worth what it says.
    ///
    /// Rounding cumulatively rather than per band keeps the stack's total
    /// height equal to the sum it represents, so the bands cannot drift away
    /// from the total as the rounding errors accumulate.
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

        return counts
    }

    /// One band on its own, rounded the same way.
    private func rowsFor(bytes: Int64, bytesPerRow: Double, cap: Int) -> Int {
        guard bytes > 0 else { return 0 }
        return min(cap, Int((Double(bytes) / bytesPerRow).rounded()))
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
    case engine, app, systemAndOthers, engineMetal, swap, compressed

    /// Floor upwards, and the two engine bands sit together at the bottom: the
    /// Metal pool is part of the engine, carved out of it rather than added, so
    /// putting them apart would misread as two separate consumers.
    static let stackOrder: [Band] = [.engineMetal, .engine, .app, .systemAndOthers]
    static let legendOrder: [Band] = [.systemAndOthers, .engineMetal, .engine, .app,
                                      .swap, .compressed]

    /// Drawn as a line rather than a filled band, and shown that way in the
    /// legend so the two kinds of thing do not look alike.
    var isLine: Bool { self == .compressed }

    var color: Color {
        switch self {
        case .engine:          Color(red: 0.37, green: 0.82, blue: 0.23)
        case .app:             Color(red: 0.94, green: 0.64, blue: 0.16)
        case .systemAndOthers: Color(red: 0.49, green: 0.49, blue: 0.51)
        case .engineMetal:     Color(red: 0.91, green: 0.35, blue: 0.62)
        case .swap:            Color(red: 0.48, green: 0.38, blue: 0.78)
        case .compressed:      Color(red: 0.42, green: 0.86, blue: 0.94)
        }
    }

    var label: String {
        switch self {
        case .engine:          loc("memory.chart.engine")
        case .app:             loc("memory.chart.app")
        case .systemAndOthers: loc("memory.chart.system")
        case .engineMetal:     loc("memory.chart.metal")
        case .swap:            loc("memory.chart.swap")
        case .compressed:      loc("memory.chart.compressed")
        }
    }
}

private extension MemorySample {
    subscript(band: Band) -> Int64 {
        switch band {
        case .engine:          engine
        case .app:             app
        case .systemAndOthers: systemAndOthers
        case .engineMetal:     engineMetal
        case .swap:            swap
        case .compressed:      compressed
        }
    }
}
