import SwiftUI

@main
struct HalationApp: App {
    @State private var app = AppState()
    @State private var localization = Localization.shared
    @Environment(\.openWindow) private var openWindow

    static let licensesWindowID = "licenses"

    init() {
        // Adds View ▸ Customize Touch Bar…, which is the only way to reach the
        // .optional items — declaring a customisation identity without this
        // leaves it unreachable.
        NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        // Registered here, not later: a click on a notification that *launched*
        // the app is only delivered if the delegate is already in place.
        Notifier.shared.prepare()
    }
    static let localizationWindowID = "debug-localizations"

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
                .task {
                    // On NSApplication rather than on a view — see AppTouchBar.
                    AppTouchBar.install(app)
                    // Clicking a notification should land on the screen that
                    // answers the question it just raised: the finished video,
                    // or the queue row whose log says what went wrong.
                    Notifier.shared.onOpen = { state in
                        app.section = state == .finished ? .library : .queue
                    }
                    Notifier.shared.onOpenDownloads = { app.section = .models }
                    await app.bootstrap()
                }
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

            // `after:` rather than `replacing:`. AppKit owns the Help menu — it
            // installs the search field and the "Halation Help" item itself —
            // and replacing the group leaves those in place while dropping our
            // item entirely, with no warning.
            CommandGroup(after: .help) {
                Button(loc("menu.licenses")) {
                    openWindow(id: Self.licensesWindowID)
                }
            }

            // Developer tools, gated on AppKit's own debug switch — see AppDebug.
            // Not localized, and deliberately so: these are for whoever is
            // working on the app, and an English menu is one less thing to keep
            // in step with translations.py.
            if AppDebug.isEnabled {
                CommandMenu("Debug") {
                    Button("Localisations (i18n)") {
                        openWindow(id: Self.localizationWindowID)
                    }
                    Button("Test Notifications (in 5s)") {
                        Notifier.shared.requestPermissionIfNeeded()
                        Notifier.shared.postTestNotifications()
                    }
                }
            }
        }

        // A plain Window rather than a sheet: licence text is something people
        // leave open beside the app while they read it, and a utility window can
        // be moved to another space and kept there.
        Window(loc("menu.licenses"), id: Self.licensesWindowID) {
            LicensesView()
                .environment(localization)
                .environment(\.locale, Locale(identifier: localization.resolved.rawValue))
                .id(localization.generation)
        }
        .windowResizability(.contentSize)

        Window("Localisations (i18n)", id: Self.localizationWindowID) {
            LocalizationInspector()
        }
        .defaultSize(width: 1100, height: 720)

        Settings {
            SettingsView()
                .environment(app)
                .environment(localization)
                .environment(\.locale, Locale(identifier: localization.resolved.rawValue))
                .id(localization.generation)
        }
    }
}
