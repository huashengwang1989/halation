import SwiftUI

/// Reports whether macOS is letting notifications through, and offers the one
/// place that can change it.
struct NotificationPermissionRow: View {
    @State private var permission: Notifier.Permission = .notAsked

    var body: some View {
        LabeledContent(loc("settings.notifications")) {
            HStack(spacing: 8) {
                switch permission {
                case .allowed:
                    Label(loc("settings.working"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                case .allowedButSilent:
                    Label(loc("settings.notifications.noBanner"),
                          systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                case .denied:
                    Label(loc("settings.notifications.denied"),
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                case .notAsked:
                    Text(loc("settings.notifications.notYetAsked"))
                        .foregroundStyle(.secondary)
                case .unavailable:
                    Text(loc("settings.notFound")).foregroundStyle(.secondary)
                }
                Button(loc("settings.notifications.test")) {
                    Notifier.shared.requestPermissionIfNeeded()
                    Notifier.shared.postSample()
                }
                Button(loc("settings.notifications.open")) {
                    Notifier.shared.openSystemSettings()
                }
            }
        }
        // Re-read on every appearance: the switch lives in System Settings, so
        // it can change while this window is open and the app is never told.
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        await Notifier.shared.refreshPermission()
        permission = Notifier.shared.permission
    }
}
