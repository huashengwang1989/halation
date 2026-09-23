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

    private var api: LocalAPIServer { app.api }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switchCard
                if api.isEnabled { connectionCard }
                capabilitiesCard
                if api.isEnabled { mcpCard }
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

    // MARK: - Connecting an agent

    private var mcpCard: some View {
        GlassCard(title: loc("automation.mcp"), systemImage: "terminal") {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("automation.mcp.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                snippet(mcpConfig, id: "mcp")

                Text(loc("automation.mcp.token"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text(loc("automation.http"))
                    .font(.caption.weight(.medium))
                snippet(curlExample, id: "curl")
            }
        }
    }

    /// Ready to paste. The token is only written in once it has been revealed —
    /// otherwise the snippet carries a placeholder, so copying it during a
    /// screen share does not hand the secret to the room.
    private var mcpConfig: String {
        """
        {
          "mcpServers": {
            "halation": {
              "command": "\(Self.serverPath)",
              "env": {
                "HALATION_URL": "\(api.baseURL)",
                "HALATION_TOKEN": "\(revealToken ? api.token : "paste-the-token-here")"
              }
            }
          }
        }
        """
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
