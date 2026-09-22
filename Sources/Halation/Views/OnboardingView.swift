import AppKit
import SwiftUI

/// First-run setup: licence acknowledgement, runtime install, model download.
/// Each step states plainly what it is about to do to the machine.
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .welcome
    @FocusState private var primaryFocused: Bool

    enum Step: Int, CaseIterable {
        case welcome, requirements, licence, runtime, models

        var title: String {
            switch self {
            case .welcome: loc("onboarding.welcome.title")
            case .requirements: loc("settings.requirements")
            case .licence: loc("onboarding.licence.title")
            case .runtime: loc("onboarding.runtime.title")
            case .models: loc("onboarding.models.title")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scrolling, so the buttons below can never be pushed off. The first
            // step already overflowed in English; a language that runs longer,
            // or a short display like an iPad used over Sidecar, would push the
            // whole footer out of reach and leave no way forward.
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(28)
            }
            .frame(maxHeight: .infinity)

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
                    .prominentButtonStyle()
                    .disabled(!canAdvance)
                    .focused($primaryFocused)
                    // Return drives the flow forward. This works whether or not the
                    // system's keyboard-navigation setting is on, which Tab does not.
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        // Taller than it was, and bounded rather than fixed: 700 is comfortable
        // on a desktop display, and the minimum keeps the footer reachable on a
        // small one. The content scrolls between the two.
        // The flexible overload throughout: `width:` is the fixed-frame form and
        // cannot be mixed with height bounds.
        .frame(minWidth: 720, idealWidth: 720, maxWidth: 720,
               minHeight: 480, idealHeight: 700, maxHeight: 700)
        .defaultFocus($primaryFocused, true)
        // `.keyboardShortcut(.cancelAction)` does not fire inside this sheet, so
        // Escape is handled explicitly. This is the macOS-native hook for it.
        .onExitCommand { close() }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .requirements: requirements
        case .licence: licence
        case .runtime: runtime
        case .models: models
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                // The app's own icon rather than a generic symbol, taken from
                // NSApplication so it follows whatever the bundle carries —
                // the layered icon on macOS 26, the flat one before it — with
                // no second copy of the artwork to keep in step.
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                Text(loc("onboarding.welcome.title"))
                    .font(.largeTitle.weight(.semibold))
            }
            Text(loc("onboarding.welcome.body"))
                .foregroundStyle(.secondary)
                // Without this the paragraph is squeezed to a single truncated
                // line whenever the dialog is shorter than its content.
                .fixedSize(horizontal: false, vertical: true)

            GlassCard(title: loc("onboarding.slowTitle"), systemImage: "clock") {
                Text(loc("onboarding.slow.body"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            GlassCard(title: loc("onboarding.diskTitle"), systemImage: "internaldrive") {
                Text(loc("onboarding.disk.body"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            // Last, and set apart. The paragraph above promises two things
            // worth knowing; this is a third card but not a third thing — it is
            // a setting offered while the user happens to be here, and sitting
            // between the other two made that copy read as a miscount.
            GlassCard(title: loc("settings.notifications"), systemImage: "bell.badge") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("settings.notifications.note"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(loc("settings.notifications.focusNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    NotificationPermissionRow()
                }
            }
            .padding(.top, 8)
        }
    }

    /// Second, immediately after the two things worth knowing, because whether
    /// the machine can run this at all decides whether the rest matters.
    private var requirements: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(loc("settings.requirements")).font(.title.weight(.semibold))
            RequirementsTables()
        }
    }

    private var licence: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc("onboarding.licence.heading"))
                .font(.title.weight(.semibold))
            Text(loc("onboarding.licence.body"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GlassCard(title: loc("onboarding.licence.restrictions"),
                      systemImage: "exclamationmark.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    Bullet(loc("onboarding.licence.bullet.territory"))
                    Bullet(loc("onboarding.licence.bullet.revenue"))
                    Bullet(loc("onboarding.licence.bullet.training"))
                    Bullet(loc("onboarding.licence.bullet.unlawful"))
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
                .help(loc("onboarding.licence.toggleHelp"))

            Text(loc("onboarding.licence.keys"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var runtime: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc("onboarding.runtime.title")).font(.title.weight(.semibold))
            Text(loc("onboarding.runtime.body"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GlassCard(title: loc("onboarding.runtime.installs"), systemImage: "shippingbox") {
                VStack(alignment: .leading, spacing: 8) {
                    Bullet(loc("onboarding.runtime.bullet.uv"))
                    Bullet(loc("onboarding.runtime.bullet.venv"))
                    Bullet(loc("onboarding.runtime.bullet.port"))
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
            Text(loc("onboarding.models.body"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GlassCard(title: loc("onboarding.models.aboutToDownload"),
                      systemImage: "arrow.down.circle") {
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
                Label(loc("onboarding.spaceTight"),
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
        case .requirements: loc("onboarding.continue")
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
        case .requirements: true
        case .licence: app.licenseAcknowledged
        case .runtime: !app.runtime.phase.isBusy
        case .models: true
        }
    }

    private func advance() {
        switch step {
        case .welcome:
            step = .requirements
        case .requirements:
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
