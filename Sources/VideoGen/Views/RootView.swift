import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    /// True when *we* collapsed the sidebar because the window got narrow. Only an
    /// automatic collapse is ever automatically undone.
    @State private var autoCollapsed = false
    /// The width regime we last acted on. We only ever act when the window *crosses*
    /// a threshold, never on every layout pass — that is what lets a manual toggle
    /// survive, since nothing re-evaluates it until the window genuinely changes size.
    @State private var regime: WidthRegime?

    private enum WidthRegime { case narrow, wide }

    /// Below this the sidebar and the detail cannot both be useful.
    private let collapseBelow: CGFloat = 1_000
    /// Wide enough that the sidebar is comfortable again. The gap between the two
    /// stops the sidebar flickering while a resize is in progress.
    private let restoreAbove: CGFloat = 1_120

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
            // Headroom for languages whose labels run longer than English —
            // "Bibliothèque", "Warteschlange" — without the user resizing.
            .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 320)
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
                        Label(isSidebarShowing ? loc("sidebar.hide") : loc("sidebar.show"),
                              systemImage: "sidebar.leading")
                    }
                    .help(isSidebarShowing ? loc("sidebar.hide") : loc("sidebar.show"))
                    .keyboardShortcut("s", modifiers: [.command, .control])
                }
                ToolbarSpacer(.fixed, placement: .navigation)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { StatusBar() }
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
            columnVisibility = isSidebarShowing ? .detailOnly : .doubleColumn
        }
        // Whatever the user chose is now the state to preserve; it is no longer ours
        // to undo when the window widens again.
        autoCollapsed = false
    }

    /// Collapses the sidebar when the window becomes too narrow for it, and restores
    /// it when the window becomes wide again — but only if we were the one who
    /// collapsed it.
    ///
    /// This acts on threshold *crossings* only. Reacting to every layout pass would
    /// undo a manual toggle on the very next frame, which is what made the button
    /// appear dead at narrow widths. The detail column is never hidden: only the
    /// sidebar is negotiable.
    private func adapt(toWidth width: CGFloat) {
        guard width > 0 else { return }

        let next: WidthRegime
        if width < collapseBelow {
            next = .narrow
        } else if width > restoreAbove {
            next = .wide
        } else {
            // Inside the hysteresis band: hold whatever we last decided.
            return
        }

        guard next != regime else { return }
        let isFirstMeasurement = regime == nil
        regime = next

        // Don't animate the window's initial sizing pass.
        let change = {
            switch next {
            case .narrow:
                guard isSidebarShowing else { return }
                autoCollapsed = true
                columnVisibility = .detailOnly
            case .wide:
                guard autoCollapsed else { return }
                autoCollapsed = false
                columnVisibility = .doubleColumn
            }
        }
        if isFirstMeasurement {
            change()
        } else {
            withAnimation(.snappy(duration: 0.2)) { change() }
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
