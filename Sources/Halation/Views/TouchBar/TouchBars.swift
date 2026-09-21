import SwiftUI

// The Touch Bar is not as dead as its hardware.
//
// No current Mac has a built-in strip, and the two that did — the 13" MacBook
// Pro M1 and M2 — cap out at 16 and 24 GB, which is less than this app's text
// encoder needs resident. So on built-in hardware the audience really is nobody.
//
// It survives elsewhere. Sidecar draws a Touch Bar along the bottom of an iPad
// used as a second display, and third-party strips such as FlexBar present
// themselves as one. Both consume the same NSTouchBar, so nothing below is
// device-specific, and both are available to a Mac with enough memory to run
// the model. The SwiftUI modifiers are current API, not a deprecated corner:
// `.touchBar`, `.touchBarItemPresence` and `.touchBarItemPrincipal` carry no
// deprecation in the macOS 27 SDK.
//
// Testing it is the awkward part. Sidecar composites the strip on the iPad
// itself, outside the Mac's framebuffer, so `screencapture` cannot see it even
// though the iPad is a display — verified by capturing both displays with
// `showTouchbar = 1` and finding neither the strip nor the sidebar. AppKit's
// Debug ▸ Dude Where's My Touch Bar is a diagnostic listing, not a simulator.
// That leaves Xcode's Window ▸ Show Touch Bar, or looking at the iPad.
//
// Every label reuses the key its screen already uses. A control that reads one
// way in the window and another on the strip is worse than no strip.
//
// The shape below — two items that never change, whose *contents* change — is
// the result of two failures, both with the same symptom: the strip appeared at
// launch, went blank on switching section, and never returned.
//
// The first attempt put a bar on each section's view. Changing section destroys
// that view, because the detail pane is a `switch` inside NavigationSplitView,
// so the bar went with it. Moving to a single bar on RootView, which outlives
// every switch, changed nothing — so teardown was not the cause. Nor was a
// poisoned customisation: the app's defaults hold no NSTouchBar entry at all.
//
// What both attempts still had was a *variable set of items*, chosen by an `if`
// on the section. Item identities are how AppKit tracks a bar, so changing the
// set asks it to rebuild one that is already installed. Here the set is fixed
// and the adaptation happens one level down, inside two SwiftUI views that
// observe AppState and redraw themselves. Nothing is added or removed, ever.

/// Installs the app's Touch Bar on NSApplication itself.
///
/// Three SwiftUI `.touchBar` placements failed the same way before this: on each
/// section's view, on RootView, and with a fixed two-item set whose contents
/// adapt. Every one appeared at launch, went blank on the first section change
/// and never came back. That ruled out the obvious causes in turn — view
/// teardown (RootView outlives every switch), stale customisation (the app's
/// defaults hold no NSTouchBar entry), and item-identity churn (the set was
/// fixed).
///
/// NSApplication is the last link in the responder chain, so a bar installed
/// here is found no matter which view holds focus and no matter what SwiftUI
/// rebuilds underneath. The items host the same SwiftUI views as before, and
/// those observe AppState, so the contents still update themselves — what
/// changes is only who owns the bar, and that owner now never goes away.
@MainActor
final class AppTouchBar: NSObject, NSTouchBarDelegate {
    private static let shared = AppTouchBar()
    private var app: AppState?

    static func install(_ app: AppState) {
        shared.app = app
        NSApplication.shared.touchBar = shared.makeTouchBar()
    }

    private func makeTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = .halationMain
        bar.defaultItemIdentifiers = [.halationControls, .flexibleSpace,
                                      .halationPrimary, .flexibleSpace]
        bar.principalItemIdentifier = .halationPrimary
        bar.customizationAllowedItemIdentifiers = [.halationControls, .halationPrimary]
        return bar
    }

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier)
    -> NSTouchBarItem? {
        guard let app else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        switch identifier {
        // customizationLabel is what the Customize Touch Bar sheet shows. An
        // NSCustomTouchBarItem without one appears there as a blank tile.
        case .halationControls:
            item.customizationLabel = loc("touchbar.controls")
            item.view = NSHostingView(rootView: TouchBarControls(app: app))
        case .halationPrimary:
            item.customizationLabel = loc("touchbar.progress")
            item.view = NSHostingView(rootView: TouchBarPrimary(app: app))
        default:
            return nil
        }
        return item
    }
}

extension NSTouchBarItem.Identifier {
    static let halationControls = NSTouchBarItem.Identifier("com.local.halation.controls")
    static let halationPrimary = NSTouchBarItem.Identifier("com.local.halation.primary")
}

extension NSTouchBar.CustomizationIdentifier {
    static let halationMain = "com.local.halation.touchbar"
}

/// The centre of the strip: start a render, or watch the one that is running.
struct TouchBarPrimary: View {
    @Bindable var app: AppState

    var body: some View {
        if app.section == .compose {
            Button {
                app.generate()
            } label: {
                Label(loc("compose.generate"), systemImage: "sparkles")
            }
            .disabled(!app.canGenerate)
        } else if let job = app.engine.activeJob {
            // A render runs for an hour or two, so this is worth showing from
            // the Library or the Models list just as much as from the queue.
            HStack(spacing: 8) {
                ProgressView(value: job.overallProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 140)
                Text(detail(job))
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        } else {
            Text(loc("touchbar.idle"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// The same two facts the status bar shows, in the same words. Assembled
    /// here rather than shared with StatusBar because the strip has room for one
    /// line and the status bar has its own layout to answer to.
    private func detail(_ job: RenderJob) -> String {
        var parts: [String] = []
        if job.totalSteps > 0 {
            parts.append(loc("status.step", "\(job.completedSteps)", "\(job.totalSteps)"))
        }
        if let remaining = job.estimatedRemaining {
            parts.append(loc("status.remaining", Format.duration(remaining)))
        }
        return parts.joined(separator: " · ")
    }
}

/// The left of the strip: what to change before a render, or what to do to one.
struct TouchBarControls: View {
    @Bindable var app: AppState

    var body: some View {
        HStack(spacing: 8) {
            if app.section == .compose {
                Picker(loc("compose.mode.title"), selection: $app.draft.mode) {
                    ForEach(GenerationMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // Seed is a toggle, not a field: nil means "fresh noise each
                // run". Typing a seed here would be miserable, but flipping
                // between repeatable and random between takes is exactly what
                // one does not want to leave the prompt for.
                Button {
                    app.draft.sampling.seed = app.draft.sampling.seed == nil
                        ? Int64.random(in: 0...4_294_967_295)
                        : nil
                } label: {
                    Image(systemName: app.draft.sampling.seed == nil ? "dice" : "lock")
                }
                .help(app.draft.sampling.seed == nil ? loc("sampling.seed.randomise")
                                                     : loc("sampling.seed.fixed"))
            } else {
                Button {
                    if let job = app.engine.activeJob { app.engine.cancel(job.id) }
                } label: {
                    Label(loc("queue.stop"), systemImage: "stop.fill")
                }
                .disabled(app.engine.activeJob == nil)

                Button {
                    if let job = app.engine.activeJob {
                        app.engine.setHeld(!job.isHeld, for: job.id)
                    }
                } label: {
                    let held = app.engine.activeJob?.isHeld ?? false
                    Image(systemName: held ? "play" : "pause")
                }
                .disabled(app.engine.activeJob == nil)

                Button {
                    app.engine.clearFinished()
                } label: {
                    Image(systemName: "xmark.bin")
                }
                .disabled(!app.engine.jobs.contains { $0.state.isTerminal })
            }
        }
    }
}
