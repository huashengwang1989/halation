import SwiftUI

/// Which model-and-engine combinations fit in how much unified memory.
///
/// One component, shown in Settings ▸ Memory and as the welcome dialog's second
/// page, because it is the single most useful fact for someone deciding whether
/// to try the app at all — and the one most easily got wrong. The weights are
/// read from the catalogue rather than written down here, so the table cannot
/// drift from the models it describes.
struct MemoryRequirementsTable: View {

    /// A combination worth listing. Not every permutation — the ones someone
    /// would actually choose, which is one row per quantization on MLX plus the
    /// two ComfyUI tasks.
    private struct Row: Identifiable {
        let id: String
        let label: String
        let weightBytes: Int64
    }

    /// Installed memory, and the share of it a model may hold.
    ///
    /// The low end of the share is the three-quarters rule; the high end is what
    /// Metal reported on a 128 GB M4 Max. Quoting the range rather than a single
    /// figure is the honest form: the fraction rises with installed memory, and
    /// only the running machine knows its own.
    private struct Machine: Identifiable {
        let id = UUID()
        let installedBytes: Int64
        let label: String
        var lowBudget: Int64 { installedBytes * 3 / 4 }
        var highBudget: Int64 { installedBytes * 84 / 100 }
    }

    private enum Verdict {
        case fits, tight, swaps

        var text: String {
            switch self {
            case .fits: loc("memory.verdict.fits")
            case .tight: loc("memory.verdict.tight")
            case .swaps: loc("memory.verdict.swaps")
            }
        }

        var tint: Color {
            switch self {
            case .fits: .green
            case .tight: .orange
            case .swaps: .red
            }
        }

        var symbol: String {
            switch self {
            case .fits: "checkmark.circle.fill"
            case .tight: "exclamationmark.triangle.fill"
            case .swaps: "xmark.circle.fill"
            }
        }
    }

    /// Generation holds well over twice the weights at peak.
    ///
    /// Measured on a live MLX render of the 4-bit set: 50 GB of catalogue
    /// weights against a kernel-reported lifetime peak of 120 GB, so 2.4. A
    /// table comparing weights alone against the budget would call that
    /// combination comfortable on a 128 GB Mac, which it is not — that render
    /// drove swap to 16 GB.
    ///
    /// One measurement, on one engine. The per-job peak the queue now records
    /// will accumulate more, and this should follow them.
    private static let peakMultiplier = 2.4

    private let gigabyte: Int64 = 1_073_741_824

    private var machines: [Machine] {
        [.init(installedBytes: 64 * gigabyte,
               label: loc("memory.table.orLess", "64 GB")),
         .init(installedBytes: 96 * gigabyte, label: "96 GB"),
         .init(installedBytes: 128 * gigabyte, label: "128 GB"),
         .init(installedBytes: 192 * gigabyte,
               label: loc("memory.table.orMore", "128 GB"))]
    }

    private var rows: [Row] {
        func bytes(_ nameKey: String) -> Int64 {
            ModelCatalog.all.first { $0.nameKey == nameKey }?.approximateResidentBytes ?? 0
        }
        // Everything an MLX run holds: the shared VAE bundle and the bf16
        // encoder are mandatory, so they are in every MLX row.
        let mlxFixed = bytes("model.name.support.mlx") + bytes("model.name.textEncoder.mlx")
        // A ComfyUI run holds both VAEs, the INT8 encoder and the turbo LoRA.
        let comfyFixed = bytes("model.name.comfy.videoVAE")
            + bytes("model.name.comfy.audioVAE")
            + bytes("model.name.comfy.textEncoder")

        return [
            .init(id: "mlx-q4", label: "MLX · FL2VA · 4-bit",
                  weightBytes: mlxFixed + bytes("model.name.fl2va.q4")),
            .init(id: "mlx-q6", label: "MLX · FL2VA · 6-bit",
                  weightBytes: mlxFixed + bytes("model.name.fl2va.q6")),
            .init(id: "mlx-q8", label: "MLX · FL2VA · 8-bit",
                  weightBytes: mlxFixed + bytes("model.name.fl2va.q8")),
            .init(id: "mlx-bf16", label: "MLX · FL2VA · bfloat16",
                  weightBytes: mlxFixed + bytes("model.name.fl2va.bf16")),
            .init(id: "comfy-fl2va", label: "ComfyUI · FL2VA · INT8",
                  weightBytes: comfyFixed + bytes("model.name.comfy.fl2va")
                      + bytes("model.name.comfy.lora.fl2va")),
            .init(id: "comfy-ref2va", label: "ComfyUI · Ref2VA · INT8",
                  weightBytes: comfyFixed + bytes("model.name.comfy.ref2va")
                      + bytes("model.name.comfy.lora.ref2va")),
        ]
    }

    /// Three outcomes, drawn at the two boundaries that change what happens
    /// rather than at two points on one scale.
    ///
    /// Under the GPU's budget, nothing pages and the render runs at full speed.
    /// Over that budget but under installed memory, macOS pages some of it and
    /// the render still finishes — measured: a 120 GB peak on a 128 GB Mac drove
    /// swap to 16 GB and completed. Over installed memory it is paging in
    /// earnest, and a render that would take an hour takes far longer.
    private func verdict(_ row: Row, on machine: Machine) -> Verdict {
        let peak = Double(row.weightBytes) * Self.peakMultiplier
        if peak <= Double(machine.highBudget) { return .fits }
        if peak <= Double(machine.installedBytes) { return .tight }
        return .swaps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                GridRow {
                    Text(loc("memory.table.combination"))
                    Text(loc("memory.table.weights"))
                    ForEach(machines) { machine in
                        Text(machine.label).gridColumnAlignment(.center)
                    }
                }
                .font(.caption.weight(.semibold))

                // Second header row: what each machine can actually give a model,
                // which is the number the verdicts are measured against.
                GridRow {
                    Text(loc("memory.table.budget"))
                        .gridCellColumns(2)
                    ForEach(machines) { machine in
                        Text("\(Format.bytes(machine.lowBudget))–\(Format.bytes(machine.highBudget))")
                            .gridColumnAlignment(.center)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                // Spanning every column: a Divider in a GridRow otherwise
                // occupies one cell and rules under the first column only.
                Divider()
                    .gridCellUnsizedAxes(.horizontal)
                    .gridCellColumns(2 + machines.count)

                ForEach(rows) { row in
                    GridRow {
                        Text(row.label)
                            .font(.caption)
                        Text(Format.bytes(row.weightBytes))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        ForEach(machines) { machine in
                            let result = verdict(row, on: machine)
                            Label(result.text, systemImage: result.symbol)
                                .labelStyle(.titleAndIcon)
                                .font(.caption2)
                                .foregroundStyle(result.tint)
                                .gridColumnAlignment(.center)
                        }
                    }
                }
            }

            Text(loc("memory.table.note"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let metal = MachineProfile.metalUsableBytes {
                Text(loc("memory.table.thisMac",
                         Format.bytes(MachineProfile.physicalBytes),
                         Format.bytes(metal)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
