import SwiftUI

/// The licence terms and the box that accepts them.
///
/// One copy, shown in two places: the welcome dialog's third page, and a sheet
/// raised from Compose when someone skipped the welcome dialog and then tried
/// to render. Two copies of a legal text is how they come to disagree, and the
/// one people did not read would be the one that mattered.
struct LicenceAgreement: View {
    @Environment(AppState.self) private var app
    /// The welcome dialog supplies its own heading and spacing; the sheet does
    /// not, so it asks for them here.
    var showsHeading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeading {
                Text(loc("onboarding.licence.heading"))
                    .font(.title.weight(.semibold))
            }
            Text(loc("onboarding.licence.body"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GlassCard(title: loc("onboarding.licence.restrictions"),
                      systemImage: "exclamationmark.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    Bullet(loc("onboarding.licence.bullet.territory"))
                    Bullet(loc("onboarding.licence.bullet.revenue"))
                    Bullet(loc("onboarding.licence.bullet.training"))
                    Bullet(loc("onboarding.licence.bullet.unlawful"))
                }
            }

            GlassCard(title: loc("licence.halation.title"),
                      systemImage: "person.badge.shield.checkmark") {
                VStack(alignment: .leading, spacing: 10) {
                    Bullet(loc("licence.halation.affiliation"))
                    Bullet(loc("licence.halation.responsibility"))
                    Bullet(loc("licence.halation.disclosure"))
                    Bullet(loc("licence.halation.liability"))
                    Bullet(loc("licence.halation.acceptance"))
                }
            }

            Link(loc("onboarding.licence.readFull"),
                 destination: .literal("https://huggingface.co/MiniMaxAI/MiniMax-H3"))

            Toggle(loc("onboarding.licence.acknowledge"),
                   isOn: Binding(get: { app.licenseAcknowledged },
                                 set: { app.licenseAcknowledged = $0 }))
                .toggleStyle(.checkbox)
                .padding(.top, 4)
                // This checkbox gates rendering. Without a shortcut, a keyboard
                // user whose system keyboard-navigation is off can reach the
                // button but never enable it — a dead end in the only mandatory
                // step.
                .keyboardShortcut("l", modifiers: .command)
                .help(loc("onboarding.licence.toggleHelp"))

            // Only in the welcome dialog: in the sheet there is no "next
            // page", so the line would describe keys that do something else.
            if showsHeading {
                Text(loc("onboarding.licence.keys"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// The same agreement as a sheet, for someone who skipped the welcome dialog.
///
/// Raised on its own rather than by reopening the welcome dialog: that would
/// walk them back through model installation they have already done, to reach
/// the one page they need.
struct LicenceSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LicenceAgreement()
                    .padding(24)
            }

            Divider()

            HStack {
                Spacer()
                Button(loc("common.done")) { dismiss() }
                    .prominentButtonStyle()
                    .keyboardShortcut(.defaultAction)
                    // Dismissing without accepting is allowed — the render
                    // simply stays blocked. A dialog with no way out but
                    // agreement is a dark pattern, and the block already says
                    // what is missing.
            }
            .padding(16)
        }
        .frame(minWidth: 620, idealWidth: 640, maxWidth: 680,
               minHeight: 480, idealHeight: 620, maxHeight: 720)
    }
}
