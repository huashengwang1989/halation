import SwiftUI

/// How much free disk each memory configuration really needs.
///
/// The weights are the same on every Mac; what changes is the swap. A machine
/// that cannot hold a render in memory pages the difference to disk, so the
/// smaller the memory the *more* disk is required — which is the opposite of
/// what anyone expects, and the reason this is a table rather than one number.
struct DiskRequirementsTable: View {

    private struct Machine: Identifiable {
        let id = UUID()
        let installedBytes: Int64
        let label: String
    }

    private let gigabyte: Int64 = 1_073_741_824

    /// The smallest set that can render anything: shared VAEs, the bf16 text
    /// encoder and the 4-bit transformer. Summed from the catalogue's download
    /// figures rather than written down, so it tracks the models.
    private var weightsBytes: Int64 {
        ["model.name.support.mlx", "model.name.textEncoder.mlx", "model.name.fl2va.q4"]
            .compactMap { key in ModelCatalog.all.first { $0.nameKey == key }?.approximateBytes }
            .reduce(0, +)
    }

    /// Python runtime, uv and the app itself — measured, and small enough that
    /// the exact figure hardly matters beside 113 GB of weights.
    private var runtimeBytes: Int64 { 650 * 1_048_576 }

    private var baseBytes: Int64 { weightsBytes + runtimeBytes }

    /// What a render is expected to hold at peak, on the same basis as the
    /// memory table — the multiplier is borrowed from it rather than repeated,
    /// so the two tables cannot drift apart when the measurement is revised.
    private var peakBytes: Int64 {
        let resident = ["model.name.support.mlx", "model.name.textEncoder.mlx",
                        "model.name.fl2va.q4"]
            .compactMap { key in
                ModelCatalog.all.first { $0.nameKey == key }?.approximateResidentBytes
            }
            .reduce(0, +)
        return Int64(Double(resident) * MemoryRequirementsTable.peakMultiplier)
    }

    private var machines: [Machine] {
        [.init(installedBytes: 64 * gigabyte, label: loc("memory.table.orLess", "64 GB")),
         .init(installedBytes: 96 * gigabyte, label: "96 GB"),
         .init(installedBytes: 128 * gigabyte, label: "128 GB"),
         .init(installedBytes: 192 * gigabyte, label: loc("memory.table.orMore", "128 GB"))]
    }

    /// Whatever the render cannot hold in memory. Measured against the generous
    /// end of the budget, so the figure is a floor rather than a worst case.
    private func swapBytes(for machine: Machine) -> Int64 {
        max(0, peakBytes - machine.installedBytes * 84 / 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                GridRow {
                    Text(loc("disk.table.installedMemory"))
                    Text(loc("disk.table.base")).gridColumnAlignment(.trailing)
                    Text(loc("disk.table.swap")).gridColumnAlignment(.trailing)
                    Text(loc("disk.table.total")).gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold))

                Divider()
                    .gridCellUnsizedAxes(.horizontal)
                    .gridCellColumns(4)

                ForEach(machines) { machine in
                    let swap = swapBytes(for: machine)
                    GridRow {
                        Text(machine.label)
                        Text(Format.bytes(baseBytes))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                        Text(swap > 0 ? Format.bytes(swap) : "—")
                            .foregroundStyle(swap > 0 ? .orange : .secondary)
                            .gridColumnAlignment(.trailing)
                        Text(Format.bytes(baseBytes + swap))
                            .fontWeight(.medium)
                            .gridColumnAlignment(.trailing)
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
            }

            Text(loc("disk.table.note", Format.bytes(weightsBytes)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
