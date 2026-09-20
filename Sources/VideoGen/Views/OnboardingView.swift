import SwiftUI

/// First-run setup: licence acknowledgement, runtime install, model download.
/// Each step states plainly what it is about to do to the machine.
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .welcome
    @FocusState private var primaryFocused: Bool

    enum Step: Int, CaseIterable {
        case welcome, licence, runtime, models

        var title: String {
            switch self {
            case .welcome: loc("onboarding.welcome.title")
            case .licence: loc("onboarding.licence.title")
            case .runtime: loc("onboarding.runtime.title")
            case .models: loc("onboarding.models.title")
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
                    Button(loc("onboarding.back")) { back() }
                        .keyboardShortcut("[", modifiers: .command)
                }
                Spacer()
                // A standard button rather than .plain: a plain button draws no
                // clear focus ring, so with keyboard navigation on there was no way
                // to tell it had focus.
                Button(loc("onboarding.skip")) { close() }
                    // Escape leaves the dialog, as it does in every macOS sheet.
                    .keyboardShortcut(.cancelAction)
                Button(primaryLabel) { advance() }
                    .buttonStyle(.glassProminent)
                    .disabled(!canAdvance)
                    .focused($primaryFocused)
                    // Return drives the flow forward. This works whether or not the
                    // system's keyboard-navigation setting is on, which Tab does not.
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 720, height: 560)
        .defaultFocus($primaryFocused, true)
        // `.keyboardShortcut(.cancelAction)` does not fire inside this sheet, so
        // Escape is handled explicitly. This is the macOS-native hook for it.
        .onExitCommand { close() }
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
            Text(loc("onboarding.welcome.title"))
                .font(.largeTitle.weight(.semibold))
            Text("""
                This app runs MiniMax H3 entirely on your own machine. Nothing is sent \
                to a server, and there is no account or API key.

                Two things are worth knowing before you start.
                """)
                .foregroundStyle(.secondary)

            GlassCard(title: loc("onboarding.slowTitle"), systemImage: "clock") {
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

            GlassCard(title: loc("onboarding.diskTitle"), systemImage: "internaldrive") {
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
            Text(loc("onboarding.licence.heading"))
                .font(.title.weight(.semibold))
            Text("""
                The weights are open, but not unconditionally. The terms you are agreeing \
                to are MiniMax's, not this app's, and it is worth reading them on the model \
                card before you download 60 GB.
                """)
                .foregroundStyle(.secondary)

            GlassCard(title: "The restrictions that actually bite", systemImage: "exclamationmark.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    Bullet("Local use is restricted in the USA, the EU, the UK and South Korea. Running the model in "
                           + "those territories needs a separate application to MiniMax.")
                    Bullet("Organisations above roughly US$20 million in annual revenue need authorisation.")
                    Bullet("Training another model on H3's output is prohibited.")
                    Bullet("Unlawful and pornographic output is prohibited by the licence, "
                           + "wherever you are. There is no server-side filter on a local run, so "
                           + "this is on you rather than on the software.")
                }
            }

            Link(loc("onboarding.licence.readFull"),
                 destination: .literal("https://huggingface.co/MiniMaxAI/MiniMax-H3"))

            Toggle(loc("onboarding.licence.acknowledge"),
                   isOn: Binding(get: { app.licenseAcknowledged },
                                 set: { app.licenseAcknowledged = $0 }))
                .toggleStyle(.checkbox)
                .padding(.top, 4)
                // This checkbox gates Continue. Without a shortcut, a keyboard user
                // whose system keyboard-navigation is off can reach the button but
                // never enable it — a dead end in the only mandatory step.
                .keyboardShortcut("l", modifiers: .command)
                .help("⌘L toggles this")

            Text("⌘L accepts · Return continues · Space activates whichever button has focus")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var runtime: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc("onboarding.runtime.title")).font(.title.weight(.semibold))
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
                    Label(loc("runtime.ready", report.pythonVersion),
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(loc("runtime.installedNotUsable"), systemImage: "exclamationmark.triangle.fill")
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
                Text(loc("runtime.notInstalledYet")).foregroundStyle(.secondary)
            }
        }
    }

    private var models: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc("onboarding.models.title")).font(.title.weight(.semibold))
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
                        VStack(alignment: .leading, spacing: 2) {
                            SpecRow(label: entry.displayName,
                                    value: Format.bytes(entry.approximateBytes))
                            Text(entry.scopeDescription)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Divider()
                    SpecRow(label: loc("onboarding.total"),
                            value: Format.bytes(app.modelStore.requiredBytes(for: ModelCatalog.recommendedBundle)),
                            isProminent: true)
                    SpecRow(label: loc("onboarding.freeOnDisk"), value: Format.bytes(app.modelStore.freeBytes))
                }
            }

            if !app.modelStore.canAccommodate(ModelCatalog.recommendedBundle) {
                Label("There may not be enough free space once scratch space for rendering is taken into account.",
                      systemImage: "externaldrive.badge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(loc("onboarding.savingTo", app.modelStore.rootURL.path(percentEncoded: false)))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Navigation

    private var primaryLabel: String {
        switch step {
        case .welcome: loc("onboarding.continue")
        case .licence: loc("onboarding.continue")
        case .runtime:
            app.runtime.phase.isReady ? loc("onboarding.continue")
                : (app.runtime.phase.isBusy ? loc("onboarding.installing") : loc("onboarding.installRuntime"))
        case .models: loc("onboarding.startDownload")
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
            close()
        }
    }

    /// Close the sheet by clearing the state that presents it. `dismiss()` proved
    /// unreliable here, and we own the binding anyway.
    private func close() {
        app.showingOnboarding = false
        dismiss()
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
                        // Selectable so a line can be picked out and pasted into a
                        // search or an issue. The Copy button beside the heading
                        // takes the whole log, including the lines shown truncated
                        // here and the ones scrolled past the 120 kept on screen.
                        .textSelection(.enabled)
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
        .accessibilityLabel(loc("settings.log.accessibility"))
        .accessibilityValue(lines.suffix(3).joined(separator: ". "))
    }
}
