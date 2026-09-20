import SwiftUI

@main
struct HalationApp: App {
    @State private var app = AppState()
    @State private var localization = Localization.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(localization)
                // Writing direction is deliberately *not* forced here. It comes
                // from the process localization, so the AppKit toolbar and the
                // SwiftUI content always agree; overriding only this half left the
                // toolbar unmirrored and collapsed it into its overflow menu.
                .environment(\.locale, Locale(identifier: localization.resolved.rawValue))
                // Rebuild on a language change so every string is re-read; without
                // this only views that happened to redraw would switch.
                .id(localization.generation)
                .task { await app.bootstrap() }
                // 200pt sidebar + 560pt detail minimum. Sized so that even with the
                // sidebar manually shown at the smallest window, both the form and
                // the summary still fit at their floors.
                .frame(minWidth: 760, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(loc("menu.newRender")) {
                    app.section = .compose
                }
                .keyboardShortcut("n")
            }
            // ⌘1…⌘4 switch sections, as in Finder and Mail.
            CommandGroup(after: .sidebar) {
                Divider()
                ForEach(Array(AppState.Section.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.label) { app.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
            }
            CommandGroup(after: .toolbar) {
                Button(loc("menu.rescanModels")) {
                    Task { await app.modelStore.scan() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button(loc("menu.revealModels")) {
                    NSWorkspace.shared.activateFileViewerSelecting([app.modelStore.rootURL])
                }
            }
        }

        Settings {
            SettingsView()
                .environment(app)
                .environment(localization)
                .environment(\.locale, Locale(identifier: localization.resolved.rawValue))
                .id(localization.generation)
        }
    }
}
