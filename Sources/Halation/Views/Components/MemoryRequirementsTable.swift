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
        /// What this engine holds at peak, as a multiple of its weights.
        let peakMultiplier: Double
        var peakBytes: Double { Double(weightBytes) * peakMultiplier }
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

    /// What a render holds at peak, as a multiple of its weights. The two
    /// engines differ so much that one number for both is simply wrong.
    ///
    /// **MLX, 2.4.** Measured on a 4-bit render: 50 GB of catalogue weights
    /// against a kernel-reported lifetime peak of 120 GB. The port holds the
    /// encoder and the transformer at once for the whole run, so the peak is
    /// the sum plus working memory. On a 128 GB Mac that render drove swap to
    /// 16 GB and still finished.
    ///
    /// **ComfyUI, 1.41.** Measured on an INT8 FL2VA render at 1344×768: 55 GB
    /// of weights against a 77.6 GB peak. ComfyUI stages its models — the
    /// footprint fell from 77 GB to 30 GB the moment sampling ended and only
    /// the VAE was still needed — so it never holds everything at once. Its
    /// peak is also a plateau rather than a spike: it sat at exactly 77.13 GB
    /// for the entire sampling phase, because the Torch MPS allocator takes a
    /// pool and reuses it.
    ///
    /// Reusing MLX's 2.4 for ComfyUI, as this table first did, called a 96 GB
    /// Mac unusable for an engine that in fact fits inside its GPU budget.
    static let mlxPeakMultiplier = 2.4
    static let comfyPeakMultiplier = 1.41

    private var machines: [MachineSize] { MachineSize.all }
    private var thisMac: MachineSize? { MachineSize.thisMac }

    /// The same rows the table draws, for the local API.
    ///
    /// Read from here rather than recomputed so the API and the table cannot
    /// give different answers about the same machine — the one thing that would
    /// make both useless. The verdict is the raw case name, not the translated
    /// label: a caller branches on it.
    /// Which models are installed is left to `/v1/models`, which already
    /// answers it; repeating it here would be a second place to get it wrong.
    @MainActor
    static func apiRows() -> [(id: String, label: String, weightBytes: Int64,
                               peakBytes: Double, verdict: String)] {
        let table = MemoryRequirementsTable()
        let mine = MachineSize.thisMac
        return table.rows.map { row in
            let verdict = mine.map { table.verdict(row, on: $0) } ?? .swaps
            return (row.id, row.label, row.weightBytes, row.peakBytes,
                    String(describing: verdict))
        }
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
                  weightBytes: mlxFixed + bytes("model.name.fl2va.q4"),
                  peakMultiplier: Self.mlxPeakMultiplier),
            .init(id: "mlx-q6", label: "MLX · FL2VA · 6-bit",
                  weightBytes: mlxFixed + bytes("model.name.fl2va.q6"),
                  peakMultiplier: Self.mlxPeakMultiplier),
            .init(id: "mlx-q8", label: "MLX · FL2VA · 8-bit",
                  weightBytes: mlxFixed + bytes("model.name.fl2va.q8"),
                  peakMultiplier: Self.mlxPeakMultiplier),
            .init(id: "mlx-bf16", label: "MLX · FL2VA · bfloat16",
                  weightBytes: mlxFixed + bytes("model.name.fl2va.bf16"),
                  peakMultiplier: Self.mlxPeakMultiplier),
            .init(id: "comfy-fl2va", label: "ComfyUI · FL2VA · INT8",
                  weightBytes: comfyFixed + bytes("model.name.comfy.fl2va")
                      + bytes("model.name.comfy.lora.fl2va"),
                  peakMultiplier: Self.comfyPeakMultiplier),
            .init(id: "comfy-ref2va", label: "ComfyUI · Ref2VA · INT8",
                  weightBytes: comfyFixed + bytes("model.name.comfy.ref2va")
                      + bytes("model.name.comfy.lora.ref2va"),
                  peakMultiplier: Self.comfyPeakMultiplier),
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
    private func verdict(_ row: Row, on machine: MachineSize) -> Verdict {
        let peak = row.peakBytes
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
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(machine.label)
                            if machine.id == thisMac?.id { ThisMacMarker() }
                        }.gridColumnAlignment(.center)
                    }
                }
                .font(.caption.weight(.semibold))

                // Second header row: what each machine can actually give a model,
                // which is the number the verdicts are measured against.
                GridRow {
                    Text(loc("memory.table.budget"))
                        .gridCellColumns(2)
                    ForEach(machines) { machine in
                        Text("\(Format.memory(machine.lowBudget))–\(Format.memory(machine.highBudget))")
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
                        Text(Format.memory(row.weightBytes))
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
                         Format.memory(MachineProfile.physicalBytes),
                         Format.memory(metal)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
