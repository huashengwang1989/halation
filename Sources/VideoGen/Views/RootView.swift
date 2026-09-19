import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// True when the app collapsed the sidebar because the window got narrow, as
    /// opposed to the user collapsing it deliberately. Only an automatic collapse is
    /// automatically undone.
    @State private var collapsedByWidth = false

    /// Below this the split view cannot give both columns a usable width.
    private let collapseBelow: CGFloat = 940
    private let restoreAbove: CGFloat = 1_080

    var body: some View {
        @Bindable var app = app

        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            // The built-in toggle collapses into an overflow menu as the window
            // narrows — exactly when it is most needed — so we remove it here and
            // supply our own, pinned to the leading edge of the detail toolbar.
            .toolbar(removing: .sidebarToggle)
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
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        toggleSidebar()
                    } label: {
                        Label(isSidebarShowing ? "Hide Sidebar" : "Show Sidebar",
                              systemImage: "sidebar.leading")
                    }
                    .help(isSidebarShowing ? "Hide the sidebar" : "Show the sidebar")
                    .keyboardShortcut("s", modifiers: [.command, .control])
                }
                ToolbarSpacer(.fixed, placement: .navigation)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            adapt(toWidth: width)
        }
        .sheet(isPresented: $app.showingOnboarding) {
            OnboardingView()
                .environment(app)
        }
    }

    private var isSidebarShowing: Bool { columnVisibility != .detailOnly }

    private func toggleSidebar() {
        withAnimation(.snappy(duration: 0.25)) {
            columnVisibility = isSidebarShowing ? .detailOnly : .all
        }
        // An explicit toggle takes ownership back from the automatic behaviour.
        collapsedByWidth = false
    }

    /// Collapses the sidebar when the window is too narrow to show both columns, and
    /// restores it only if we were the one who collapsed it. The gap between the two
    /// thresholds stops the sidebar flickering while the window is being resized.
    private func adapt(toWidth width: CGFloat) {
        guard width > 0 else { return }
        if width < collapseBelow, columnVisibility != .detailOnly {
            collapsedByWidth = true
            withAnimation(.snappy(duration: 0.2)) { columnVisibility = .detailOnly }
        } else if width > restoreAbove, collapsedByWidth {
            collapsedByWidth = false
            withAnimation(.snappy(duration: 0.2)) { columnVisibility = .all }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
