import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app

        NavigationSplitView {
            List(selection: $app.section) {
                Section {
                    ForEach(AppState.Section.allCases) { section in
                        Label(section.label, systemImage: section.symbolName)
                            .badge(badge(for: section))
                            .tag(section)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .safeAreaInset(edge: .bottom) { SidebarStatus() }
        } detail: {
            Group {
                switch app.section {
                case .compose: ComposeView()
                case .queue:   QueueView()
                case .library: LibraryView()
                case .models:  ModelsView()
                }
            }
            .navigationTitle(app.section.label)
        }
        .sheet(isPresented: $app.showingOnboarding) {
            OnboardingView()
                .environment(app)
        }
    }

    /// Counts that matter at a glance: work in flight, not totals.
    private func badge(for section: AppState.Section) -> Int {
        switch section {
        case .queue:
            app.engine.jobs.count { !$0.state.isTerminal }
        case .models:
            app.downloads.pendingCount
        default:
            0
        }
    }
}

/// Persistent footer: runtime health and what the machine is doing right now.
private struct SidebarStatus: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let job = app.engine.activeJob {
                ProgressView(value: job.overallProgress)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                if let remaining = job.estimatedRemaining {
                    Text("about \(Format.duration(remaining)) left")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var statusColor: Color {
        switch app.runtime.phase {
        case .ready(let report): report.h3Usable ? .green : .orange
        case .installing: .blue
        case .failed: .red
        case .missing, .unknown: .orange
        }
    }

    private var statusText: String {
        switch app.runtime.phase {
        case .ready(let report):
            if let job = app.engine.activeJob { return job.state.label }
            return report.h3Usable ? "Ready" : "Runtime incomplete"
        case .installing(let step, _): return step
        case .failed: return "Runtime error"
        case .missing: return "Runtime not installed"
        case .unknown: return "Checking…"
        }
    }
}
