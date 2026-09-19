import SwiftUI

/// First-run setup: licence acknowledgement, runtime install, model download.
/// Each step states plainly what it is about to do to the machine.
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .welcome

    enum Step: Int, CaseIterable {
        case welcome, licence, runtime, models

        var title: String {
            switch self {
            case .welcome: "Local video generation"
            case .licence: "Model licence"
            case .runtime: "Python runtime"
            case .models: "Model weights"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)

            Divider()

            HStack {
                if step != .welcome {
                    Button("Back") { back() }.buttonStyle(.glass)
                }
                Spacer()
                Button("Skip setup") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button(primaryLabel) { advance() }
                    .buttonStyle(.glassProminent)
                    .disabled(!canAdvance)
            }
            .padding(16)
        }
        .frame(width: 720, height: 560)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .licence: licence
        case .runtime: runtime
        case .models: models
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Generate video on this Mac")
                .font(.largeTitle.weight(.semibold))
            Text("""
                This app runs MiniMax H3 entirely on your own machine. Nothing is sent \
                to a server, and there is no account or API key.

                Two things are worth knowing before you start.
                """)
                .foregroundStyle(.secondary)

            GlassCard(title: "Renders take hours, not seconds", systemImage: "clock") {
                Text("""
                    H3 is a 33-billion-parameter diffusion model. On an M4 Max, a 5-second \
                    clip at the fast-preview settings takes roughly one to two hours; at \
                    50 steps it is an overnight job. The queue is built for that — it keeps \
                    running while you use the Mac for other things, and it survives a quit.
                    """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            GlassCard(title: "Setup is a large download", systemImage: "internaldrive") {
                Text("""
                    The recommended set of weights is a little over 100 GB — most of it the \
                    Qwen3-VL-32B text encoder. They are stored in a shared folder so other \
                    projects on this Mac can use the same copy.
                    """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var licence: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MiniMax H3 Community License")
                .font(.title.weight(.semibold))
            Text("""
                The weights are open, but not unconditionally. The terms you are agreeing \
                to are MiniMax's, not this app's, and it is worth reading them on the model \
                card before you download 60 GB.
                """)
                .foregroundStyle(.secondary)

            GlassCard(title: "The restrictions that actually bite", systemImage: "exclamationmark.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    Bullet("Local use is restricted in the USA, the EU, the UK and South Korea. Running the model in those territories needs a separate application to MiniMax.")
                    Bullet("Organisations above roughly US$20 million in annual revenue need authorisation.")
                    Bullet("Training another model on H3's output is prohibited.")
                    Bullet("Unlawful and pornographic output is prohibited by the licence, wherever you are. There is no server-side filter on a local run, so this is on you rather than on the software.")
                }
            }

            Link("Read the full licence on Hugging Face",
                 destination: URL(string: "https://huggingface.co/MiniMaxAI/MiniMax-H3")!)

            Toggle("I have read the licence and I am entitled to use these weights where I am",
                   isOn: Binding(get: { app.licenseAcknowledged },
                                 set: { app.licenseAcknowledged = $0 }))
                .toggleStyle(.checkbox)
                .padding(.top, 4)
        }
    }

    private var runtime: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Python runtime").font(.title.weight(.semibold))
            Text("""
                H3 has no native Swift implementation. The app drives the MLX port through \
                its own private Python environment, kept separate from any Python you \
                already have so it cannot break yours or be broken by it.
                """)
                .foregroundStyle(.secondary)

            GlassCard(title: "What gets installed", systemImage: "shippingbox") {
                VStack(alignment: .leading, spacing: 8) {
                    Bullet("uv, into this app's Application Support folder")
                    Bullet("A Python 3.12 virtual environment, about 1.5 GB with MLX")
                    Bullet("minimax-h3-mlx, the Apache-2.0 Apple-silicon port")
                }
            }

            switch app.runtime.phase {
            case .installing(let stepName, let fraction):
                VStack(alignment: .leading, spacing: 8) {
                    if let fraction {
                        ProgressView(value: fraction) { Text(stepName) }
                    } else {
                        ProgressView { Text(stepName) }
                    }
                    LogTail(lines: app.runtime.installLog)
                }
            case .ready(let report):
                if report.h3Usable {
                    Label("Runtime ready — Python \(report.pythonVersion), MLX on Metal",
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Installed, but not usable yet", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        ForEach(report.problems, id: \.self) { problem in
                            Text("• \(problem)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    LogTail(lines: app.runtime.installLog)
                }
            case .missing, .unknown:
                Text("Not installed yet.").foregroundStyle(.secondary)
            }
        }
    }

    private var models: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model weights").font(.title.weight(.semibold))
            Text("""
                The recommended set is the 4-bit FL2VA transformer plus the bfloat16 text \
                encoder and the shared VAEs — the fastest combination the MLX port can \
                currently load. Higher-precision transformers can be added later from the \
                Models tab without re-downloading the encoder.
                """)
                .foregroundStyle(.secondary)

            GlassCard(title: "About to download", systemImage: "arrow.down.circle") {
                VStack(spacing: 8) {
                    ForEach(ModelCatalog.recommendedBundle) { entry in
                        SpecRow(label: entry.repoID, value: Format.bytes(entry.approximateBytes))
                    }
                    Divider()
                    SpecRow(label: "Total",
                            value: Format.bytes(app.modelStore.requiredBytes(for: ModelCatalog.recommendedBundle)),
                            isProminent: true)
                    SpecRow(label: "Free on disk", value: Format.bytes(app.modelStore.freeBytes))
                }
            }

            if !app.modelStore.canAccommodate(ModelCatalog.recommendedBundle) {
                Label("There may not be enough free space once scratch space for rendering is taken into account.",
                      systemImage: "externaldrive.badge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Saving to \(app.modelStore.rootURL.path(percentEncoded: false))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Navigation

    private var primaryLabel: String {
        switch step {
        case .welcome: "Continue"
        case .licence: "Continue"
        case .runtime:
            app.runtime.phase.isReady ? "Continue"
                : (app.runtime.phase.isBusy ? "Installing…" : "Install Runtime")
        case .models: "Start Download"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .welcome: true
        case .licence: app.licenseAcknowledged
        case .runtime: !app.runtime.phase.isBusy
        case .models: true
        }
    }

    private func advance() {
        switch step {
        case .welcome:
            step = .licence
        case .licence:
            step = .runtime
        case .runtime:
            if app.runtime.phase.isReady {
                step = .models
            } else {
                Task {
                    await app.runtime.install()
                    if app.runtime.phase.isReady { step = .models }
                }
            }
        case .models:
            app.downloads.enqueue(ModelCatalog.recommendedBundle)
            app.section = .models
            dismiss()
        }
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }
}

private struct Bullet: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LogTail: View {
    var lines: [String]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(Array(lines.suffix(120).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(8)
        }
        .defaultScrollAnchor(.bottom)
        .frame(height: 120)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
        // Announced as one element: stepping through a hundred build lines one at
        // a time is worse than useless.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Installation log")
        .accessibilityValue(lines.suffix(3).joined(separator: ". "))
    }
}
