import SwiftUI

/// How much free disk each memory configuration really needs.
///
/// The weights are the same on every Mac; what changes is the swap. A machine
/// that cannot hold a render in memory pages the difference to disk, so the
/// smaller the memory the *more* disk is required — which is the opposite of
/// what anyone expects, and the reason this is a table rather than one number.
struct DiskRequirementsTable: View {

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

    /// Wheels uv keeps while it builds the runtime. Transient: the Cache tab
    /// empties it, and this Mac's own was 3.56 GB when it was last read.
    private var uvCacheBytes: Int64 { 3_400 * 1_048_576 }

    /// A render writes almost nothing: frames go straight down a pipe to the
    /// encoder. Listed anyway, because the surprise is the point.
    private var scratchBytes: Int64 { 10 * 1_048_576 }

    private var baseBytes: Int64 { weightsBytes + runtimeBytes }

    /// The most disk the app ever needs at once — which is during installation,
    /// not during a render, because the uv cache has not been cleared yet.
    private var setupPeakBytes: Int64 { baseBytes + uvCacheBytes + scratchBytes }

    private func catalogBytes(_ nameKey: String) -> Int64 {
        ModelCatalog.all.first { $0.nameKey == nameKey }?.approximateBytes ?? 0
    }

    /// One line of the breakdown. `isTotal` marks the two subtotals, which are
    /// ruled off and weighted rather than indented, so the eye can find them.
    private struct Item: Identifiable {
        let id = UUID()
        let label: String
        let bytes: Int64
        var isTotal = false
        var isTransient = false
    }

    private var items: [Item] {
        [.init(label: loc("disk.item.vae"),
               bytes: catalogBytes("model.name.support.mlx")),
         .init(label: loc("disk.item.encoder"),
               bytes: catalogBytes("model.name.textEncoder.mlx")),
         .init(label: loc("disk.item.transformer"),
               bytes: catalogBytes("model.name.fl2va.q4")),
         .init(label: loc("disk.item.runtime"), bytes: runtimeBytes),
         .init(label: loc("disk.item.persistent"), bytes: baseBytes, isTotal: true),
         .init(label: loc("disk.item.uvCache"), bytes: uvCacheBytes, isTransient: true),
         .init(label: loc("disk.item.scratch"), bytes: scratchBytes, isTransient: true),
         .init(label: loc("disk.item.setupPeak"), bytes: setupPeakBytes, isTotal: true)]
    }

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
        return Int64(Double(resident) * MemoryRequirementsTable.mlxPeakMultiplier)
    }

    private var machines: [MachineSize] { MachineSize.all }
    private var thisMac: MachineSize? { MachineSize.thisMac }

    /// Whatever the render cannot hold in memory. Measured against the generous
    /// end of the budget, so the figure is a floor rather than a worst case.
    private func swapBytes(for machine: MachineSize) -> Int64 {
        max(0, peakBytes - machine.installedBytes * 84 / 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            breakdown
            perMachine
        }
    }

    /// What the floor is made of. Worth itemising because one line — the bf16
    /// text encoder — is most of it, and nothing about the total says so.
    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(loc("disk.table.breakdown"))
                .font(.caption.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                ForEach(items) { item in
                    if item.isTotal {
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                            .gridCellColumns(2)
                    }
                    GridRow {
                        Text(item.label)
                            .foregroundStyle(item.isTransient ? .secondary : .primary)
                        Text(item.isTransient
                             ? "+" + Format.bytes(item.bytes)
                             : Format.bytes(item.bytes))
                            .fontWeight(item.isTotal ? .medium : .regular)
                            .foregroundStyle(item.isTotal ? .primary : .secondary)
                            .gridColumnAlignment(.trailing)
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
            }
        }
    }

    private var perMachine: some View {
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
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(machine.label)
                            if machine.id == thisMac?.id { ThisMacMarker() }
                        }
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
