import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            RuntimeSettings()
                .tabItem { Label("Runtime", systemImage: "terminal") }
            ComfyUISettings()
                .tabItem { Label("ComfyUI", systemImage: "square.stack.3d.up") }
            AdvancedSettings()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 620, height: 460)
    }
}

private struct GeneralSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Form {
            Section("Folders") {
                LabeledContent("Models") {
                    HStack {
                        Text(app.modelStore.rootURL.path(percentEncoded: false))
                            .lineLimit(1).truncationMode(.middle)
                        Button("Change…") { chooseModels() }
                    }
                }
                LabeledContent("Output") {
                    HStack {
                        Text(app.library.outputFolder.path(percentEncoded: false))
                            .lineLimit(1).truncationMode(.middle)
                        Button("Change…") { chooseOutput() }
                    }
                }
            }

            Section("Queue") {
                Text("Renders hold tens of gigabytes of weights in memory, so only one "
                     + "runs at a time. Hold or stop an individual render from its own "
                     + "row in the Queue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseModels() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = app.modelStore.rootURL
        if panel.runModal() == .OK, let url = panel.url { app.modelStore.setRoot(url) }
    }

    private func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = app.library.outputFolder
        if panel.runModal() == .OK, let url = panel.url { app.library.outputFolder = url }
    }
}

private struct RuntimeSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Form {
            Section("Status") {
                switch app.runtime.phase {
                case .ready(let report):
                    LabeledContent("Python", value: report.pythonVersion)
                    LabeledContent("Architecture", value: report.machine)
                    LabeledContent("MLX on Metal", value: report.mlxMetalOK ? "Working" : "Not working")
                    LabeledContent("ffmpeg", value: report.ffmpegPath ?? "Not found")
                    LabeledContent("H3 pipeline", value: report.h3Usable ? "Detected" : "Not detected")
                    ForEach(report.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                case .installing(let step, _):
                    LabeledContent("State", value: step)
                case .failed(let message):
                    Label(message, systemImage: "xmark.octagon").foregroundStyle(.red)
                case .missing:
                    Text("Not installed.")
                case .unknown:
                    Text("Checking…")
                }
            }

            Section {
                HStack {
                    Button("Re-check") { Task { await app.runtime.runDoctor() } }
                    Button("Repair") { Task { await app.runtime.install() } }
                    Button("Rebuild from Scratch", role: .destructive) {
                        Task { await app.runtime.install(reinstall: true) }
                    }
                }
                .disabled(app.runtime.phase.isBusy)

                Text("Rebuilding deletes and recreates the Python environment. It does not touch downloaded weights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !app.runtime.installLog.isEmpty {
                Section("Log") { LogTail(lines: app.runtime.installLog) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AdvancedSettings: View {
    @AppStorage("h3RepoOverride") private var repoOverride = ""

    var body: some View {
        Form {
            Section("MiniMax-H3 port") {
                TextField("Checkout path", text: $repoOverride,
                          prompt: Text("Leave empty to use the installed package"))
                Text("""
                    Point this at a local clone of PipeNetwork/minimax-h3-mlx to run against \
                    your own build of the port. The app discovers the pipeline's parameters \
                    at launch, so a fork with different flag names still works.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Folders") {
                Button("Reveal Application Support Folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([RuntimeManager.supportDirectory])
                }
                Text("Holds the Python environment, the render queue, and scratch files for in-flight renders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// ComfyUI is a second, separate runtime: it needs PyTorch, which cannot share an
/// environment with MLX, and the user's own ComfyUI must be left alone.
private struct ComfyUISettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Form {
            Section("Status") {
                switch app.comfyRuntime.phase {
                case .ready(let version):
                    LabeledContent("ComfyUI", value: version)
                    LabeledContent("Server",
                                   value: app.comfyRuntime.isServerRunning
                                        ? "running on port \(app.comfyRuntime.port)"
                                        : "not running")
                case .installing(let step):
                    LabeledContent("State", value: step)
                case .failed(let message):
                    Label(message, systemImage: "xmark.octagon").foregroundStyle(.red)
                case .missing:
                    Text("Not installed.")
                case .unknown:
                    Text("Checking…")
                }
                LabeledContent("Weights", value: app.comfyRuntime.modelsRoot.path)
                    .textSelection(.enabled)
            }

            Section {
                Text("Reference mode runs here rather than on MLX, whose pipeline accepts "
                     + "keyframes only. ComfyUI also loads the 4-step turbo LoRAs, which is "
                     + "what makes reference renders practical: about 25 minutes for 5 seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Install") { Task { await app.comfyRuntime.install() } }
                        .disabled(app.comfyRuntime.phase.isBusy || app.comfyRuntime.isInstalled)
                    Button("Repair") { Task { await app.comfyRuntime.install() } }
                        .disabled(app.comfyRuntime.phase.isBusy || !app.comfyRuntime.isInstalled)
                    Button("Stop Server", role: .destructive) {
                        Task { await app.comfyRuntime.stopServer() }
                    }
                    .disabled(!app.comfyRuntime.isServerRunning)
                }
                Text("The app's own headless ComfyUI, kept apart from any you have installed "
                     + "yourself. The server starts on demand and stops with the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !app.comfyRuntime.installLog.isEmpty {
                Section("Log") { LogTail(lines: app.comfyRuntime.installLog) }
            }
        }
        .formStyle(.grouped)
    }
}
