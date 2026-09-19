import SwiftUI

@main
struct VideoGenApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .task { await app.bootstrap() }
                .frame(minWidth: 1_040, minHeight: 680)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Render") {
                    app.section = .compose
                }
                .keyboardShortcut("n")
            }
            CommandGroup(after: .toolbar) {
                Button("Rescan Models Folder") {
                    Task { await app.modelStore.scan() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Reveal Models Folder in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([app.modelStore.rootURL])
                }
            }
        }

        Settings {
            SettingsView()
                .environment(app)
        }
    }
}
