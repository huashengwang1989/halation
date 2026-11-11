import SwiftUI

/// The Automation page: a local API another program can talk to.
///
/// Its own page rather than a Settings tab because it is not a preference. It
/// opens a port, hands out a token and can be given permission to start work —
/// and the person switching it on needs to see what it exposes while they
/// decide, not after. So the switches and the list of what they grant live on
/// one screen.
struct AutomationView: View {
    @Environment(AppState.self) private var app
    @State private var revealToken = false
    @State private var copied: String?
    /// Whether `~/.local/bin/halation` leads to this app's binary. Checked on a
    /// timer, because the step is done in Terminal and nothing tells the app.
    @State private var commandLinked = false

    private var api: LocalAPIServer { app.api }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switchCard
                if api.isEnabled { connectionCard }
                guideCard
                capabilitiesCard
            }
            .padding(20)
            // Capped so the lines stay readable, then pinned left. A bare
            // `maxWidth:` centres what it caps, which left the whole page
            // drifting away from the sidebar.
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .softScrollEdge(for: .top)
        .statusBarInset()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Switches

    private var switchCard: some View {
        // The explanation goes above the switch, not in the card's footnote
        // slot: a footnote lands under the controls, so the sentence saying
        // what this is arrived after the decision it informs.
        GlassCard(title: loc("automation.title"),
                  systemImage: "point.3.connected.trianglepath.dotted") {
            @Bindable var api = app.api
            VStack(alignment: .leading, spacing: 14) {
                Text(loc("automation.footnote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(loc("automation.enable"), isOn: $api.isEnabled)
                    .toggleStyle(.switch)

                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(statusTint)

                Divider()

                Toggle(loc("automation.writes"), isOn: $api.allowsWrites)
                    .toggleStyle(.switch)
                    .disabled(!api.isEnabled)
                Text(loc("automation.writes.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if api.allowsWrites {
                    Stepper(value: $api.maxQueueDepth, in: 1...10) {
                        Text(loc("automation.depth", "\(api.maxQueueDepth)"))
                    }
                    .disabled(!api.isEnabled)
                    Text(loc("automation.depth.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var statusLine: String {
        switch api.status {
        case .off: loc("automation.status.off")
        case .running(let port):
            loc("automation.status.running", "\(port)", "\(api.requestsServed)")
        case .failed(let message): message
        }
    }

    private var statusTint: Color {
        switch api.status {
        case .off: .secondary
        case .running: .green
        case .failed: .orange
        }
    }

    // MARK: - Connection

    private var connectionCard: some View {
        GlassCard(title: loc("automation.connection"), systemImage: "key.horizontal") {
            @Bindable var api = app.api
            VStack(alignment: .leading, spacing: 12) {
                field(label: loc("automation.address"), value: api.baseURL, id: "url")

                LabeledContent(loc("automation.port")) {
                    TextField("", value: $api.port, format: .number.grouping(.never))
                        .frame(width: 90)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }

                // Hidden until asked for. It is the whole of the security here,
                // and a screen share or a screenshot is the likeliest way it
                // gets away from someone.
                LabeledContent(loc("automation.token")) {
                    HStack(spacing: 8) {
                        Text(revealToken ? api.token : String(repeating: "•", count: 24))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        // The eye, as on any password field: the control is
                        // recognised on sight, and a word here would be one
                        // more thing to translate for no gain.
                        Button {
                            revealToken.toggle()
                        } label: {
                            Image(systemName: revealToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(revealToken ? loc("automation.hide") : loc("automation.reveal"))
                        .accessibilityLabel(revealToken ? loc("automation.hide")
                                                        : loc("automation.reveal"))
                        copyButton(api.token, id: "token")
                    }
                }

                HStack {
                    Button(loc("automation.regenerate"), systemImage: "arrow.clockwise") {
                        api.regenerateToken()
                        revealToken = false
                    }
                    Spacer()
                }
                Text(loc("automation.token.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - What it exposes

    private var capabilitiesCard: some View {
        GlassCard(title: loc("automation.exposes"), systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Capability.all, id: \.route) { capability in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: capability.writes
                              ? "square.and.pencil" : "eye")
                            .imageScale(.small)
                            .foregroundStyle(capability.writes ? .orange : .secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(capability.route)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Text(capability.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .opacity(capability.writes && !api.allowsWrites ? 0.45 : 1)
                }

                Divider()
                Text(loc("automation.exposes.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The routes, described where someone is deciding whether to switch them
    /// on. Written here rather than fetched from `/v1/health` so the page says
    /// what it grants even while the server is off.
    private struct Capability {
        let route: String
        let summary: String
        var writes = false

        static var all: [Capability] {
            [
                .init(route: "GET /v1/machine", summary: loc("automation.cap.machine")),
                .init(route: "POST /v1/estimate", summary: loc("automation.cap.estimate")),
                .init(route: "GET /v1/models", summary: loc("automation.cap.models")),
                .init(route: "GET /v1/library", summary: loc("automation.cap.library")),
                .init(route: "GET /v1/jobs", summary: loc("automation.cap.jobs")),
                .init(route: "POST /v1/renders", summary: loc("automation.cap.submit"),
                      writes: true),
                .init(route: "POST /v1/library/{id}/reproduce",
                      summary: loc("automation.cap.reproduce"), writes: true),
                .init(route: "POST /v1/jobs/{id}/cancel",
                      summary: loc("automation.cap.cancel"), writes: true),
            ]
        }
    }

    // MARK: - Step-by-step guide

    /// Setting up the command and an agent, one step at a time.
    ///
    /// Every step is something the user pastes into Terminal themselves rather
    /// than something the app does for them: nothing here writes outside the
    /// app until they choose to, and each step can be seen before it is run.
    /// Steps the app can check get a tick when they are done.
    private var guideCard: some View {
        GlassCard(title: loc("automation.guide"), systemImage: "terminal") {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc("automation.guide.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                step(1, loc("automation.step.api"), done: api.status.isRunning) {
                    caption(loc("automation.step.api.detail"))
                }

                step(2, loc("automation.step.link"), done: commandLinked) {
                    caption(loc("automation.step.link.detail"))
                    snippet(linkCommand, id: "link")
                    caption(loc("automation.step.path"))
                    snippet(#"echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc"#,
                            id: "path")
                }

                step(3, loc("automation.step.check"), done: nil) {
                    caption(loc("automation.step.check.detail"))
                    snippet("halation status", id: "check")
                }

                step(4, loc("automation.step.agent"), done: nil) {
                    caption(loc("automation.step.agent.detail"))
                    snippet(claudeCodeCommand, id: "claude")
                    snippet(mcpConfig, id: "mcp")
                }

                step(5, loc("automation.step.try"), done: nil) {
                    caption(loc("automation.step.try.detail"))
                    snippet(tryCommand, id: "try")
                }

                Divider()

                Text(loc("automation.http"))
                    .font(.caption.weight(.medium))
                snippet(curlExample, id: "curl")
                caption(loc("automation.mcp.token"))
            }
        }
        .task {
            while !Task.isCancelled {
                commandLinked = Self.isCommandLinked
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func step<Content: View>(_ number: Int, _ title: String, done: Bool?,
                                     @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done == true ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title3)
                .foregroundStyle(done == true ? .green : .secondary)
                .accessibilityLabel(done == true ? loc("automation.step.done") : "\(number)")
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.callout.weight(.semibold))
                content()
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Into `~/.local/bin`, which needs no administrator password, unlike
    /// `/usr/local/bin`. A link rather than a copy, so updating the app updates
    /// the command — and it goes wherever the app is, which is why moving the
    /// app means running it again.
    private var linkCommand: String {
        #"mkdir -p ~/.local/bin && ln -sf "\#(Self.serverPath)" ~/.local/bin/halation"#
    }

    private var tryCommand: String {
        #"halation render "A paper boat drifting down a rain gutter, close-up" "#
            + "--resolution 384 --cache reuse --wait"
    }

    private var claudeCodeCommand: String {
        #"claude mcp add halation -- "\#(Self.serverPath)""#
    }

    /// No token and no address: the server reads both from this app's settings,
    /// so the config cannot go stale when the token is regenerated.
    private var mcpConfig: String {
        """
        {
          "mcpServers": {
            "halation": {
              "command": "\(Self.serverPath)"
            }
          }
        }
        """
    }

    private static var isCommandLinked: Bool {
        let link = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".local/bin/halation")
        return link.resolvingSymlinksInPath().path(percentEncoded: false)
            == URL(fileURLWithPath: serverPath).resolvingSymlinksInPath().path(percentEncoded: false)
    }

    /// Beside the running app, whether that is in Applications or a build
    /// directory — so the path is right without anyone being asked where they
    /// put the app.
    private static var serverPath: String {
        Bundle.main.bundleURL
            .appending(path: "Contents/MacOS/halation-mcp")
            .path(percentEncoded: false)
    }

    private var curlExample: String {
        """
        curl -s \(api.baseURL)/v1/machine \\
          -H "Authorization: Bearer \(revealToken ? api.token : "$HALATION_TOKEN")"
        """
    }

    // MARK: - Small pieces

    private func field(label: String, value: String, id: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                copyButton(value, id: id)
            }
        }
    }

    private func snippet(_ text: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.28), in: .rect(cornerRadius: 8))
            HStack {
                Spacer()
                copyButton(text, id: id)
            }
        }
    }

    private func copyButton(_ value: String, id: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copied = id
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copied == id { copied = nil }
            }
        } label: {
            Label(copied == id ? loc("automation.copied") : loc("common.copy"),
                  systemImage: copied == id ? "checkmark" : "doc.on.doc")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help(loc("common.copy"))
    }
}
