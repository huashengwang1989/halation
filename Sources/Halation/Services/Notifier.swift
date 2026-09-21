import AppKit
import Foundation
import UserNotifications

/// Tells the user a render ended, when they are not looking at the app.
///
/// Worth having here more than in most apps: a render runs for one to two hours,
/// so by the time it ends nobody is watching the queue. That is also why the
/// permission is asked for on the first enqueue rather than at launch — at that
/// moment the request explains itself, and someone who never renders is never
/// asked at all.
///
/// Banners are shown even while Halation is the front app, which takes an
/// explicit opt-in: macOS suppresses foreground notifications unless the
/// delegate asks for them. Letting the default stand seemed reasonable — the
/// queue is right there — but it fails in practice. Someone waiting on a render
/// is not staring at the queue; they have the window open behind a browser, or
/// they are on another Space, and by macOS's reckoning the app is still
/// "front". The result was a feature that appeared to do nothing.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Called when a render notification is clicked, with the state it reported.
    /// Set by the app, which knows how to bring the right section forward.
    var onOpen: ((RenderJob.State) -> Void)?
    /// Called when a download notification is clicked.
    var onOpenDownloads: (() -> Void)?

    private var askedForPermission = false

    /// What macOS currently allows, for the row in Settings ▸ General.
    ///
    /// Worth showing, because the failure it describes is silent: with
    /// notifications switched off the app posts as usual and nothing arrives,
    /// which looks exactly like a bug in the app. macOS owns this switch, so the
    /// most the app can do is report it and offer to open the right pane.
    /// `allowedButSilent` is the one that matters in practice. macOS keeps
    /// permission and alert style as separate switches, so a user can allow
    /// notifications and still have the style set to None — delivery succeeds,
    /// Notification Center records it, and nothing ever appears on screen. From
    /// inside the app that is indistinguishable from a bug.
    enum Permission { case notAsked, allowed, allowedButSilent, denied, unavailable }

    private(set) var permission: Permission = .notAsked

    func refreshPermission() async {
        guard isAvailable else { permission = .unavailable; return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            let silent = settings.alertStyle == .none
                || settings.alertSetting == .disabled
            permission = silent ? .allowedButSilent : .allowed
        case .denied:
            permission = .denied
        case .notDetermined:
            permission = .notAsked
        @unknown default:
            permission = .notAsked
        }
    }

    /// Opens System Settings at the pane that owns this decision.
    func openSystemSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// UNUserNotificationCenter traps when the process has no app bundle —
    /// `swift run` straight from the package, for instance. Everything here is a
    /// no-op in that case rather than a crash, because a developer running the
    /// executable directly should not have to care about notifications.
    private var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Called at launch. Registering the delegate this early is what lets a
    /// click on a notification that *launched* the app still be delivered.
    func prepare() {
        FileHandle.standardError.write(Data("""
        [Notifier] bundleID=\(Bundle.main.bundleIdentifier ?? "nil")         url=\(Bundle.main.bundleURL.lastPathComponent) available=\(isAvailable)

        """.utf8))
        guard isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asked once, when the user first queues something.
    func requestPermissionIfNeeded() {
        guard isAvailable, !askedForPermission else { return }
        askedForPermission = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error { Self.log("authorization failed: \(error)") }
                Self.log("authorization granted: \(granted)")
                Task { @MainActor in await self.refreshPermission() }
            }
    }

    func renderFinished(_ job: RenderJob) {
        post(job: job,
             title: loc("notify.finished.title"),
             body: job.elapsed.map { loc("queue.took", Format.duration($0)) } ?? "")
    }

    func renderFailed(_ job: RenderJob) {
        post(job: job,
             title: loc("notify.failed.title"),
             body: job.failureMessage ?? loc("notify.failed.body"))
    }

    /// Fires one of each kind, a few seconds out.
    ///
    /// The delay is the point: macOS suppresses a notification while its app is
    /// in front, so without time to switch away you would see nothing and
    /// conclude it was broken. Reached from Debug ▸ Test Notifications.
    /// One harmless notification, for the button in Settings and onboarding.
    ///
    /// Its purpose is to answer "will I actually see these?" now, rather than
    /// after waiting two hours for a render to answer it.
    func postSample() {
        post(id: UUID().uuidString, title: loc("notify.test.title"),
             subtitle: "", body: loc("notify.test.body"),
             userInfo: [:], after: nil)
    }

    func postTestNotifications(after seconds: TimeInterval?) {
        // Staggered only when delayed. Fired immediately they arrive together,
        // which is what Notification Center would do with them anyway.
        func delay(_ step: Double) -> TimeInterval? { seconds.map { $0 + step } }
        post(id: UUID().uuidString, title: loc("notify.finished.title"),
             subtitle: "A test render", body: loc("queue.took", Format.duration(4_231)),
             userInfo: ["state": RenderJob.State.finished.rawValue], after: delay(0))
        post(id: UUID().uuidString, title: loc("notify.failed.title"),
             subtitle: "A test render", body: loc("notify.failed.body"),
             userInfo: ["state": RenderJob.State.failed.rawValue], after: delay(1))
        post(id: UUID().uuidString, title: loc("notify.download.finished.title"),
             subtitle: "A test model", body: Format.bytes(67 * 1_073_741_824),
             userInfo: ["section": "models"], after: delay(2))
        post(id: UUID().uuidString, title: loc("notify.download.failed.title"),
             subtitle: "A test model", body: "The network connection was lost.",
             userInfo: ["section": "models"], after: delay(3))
    }

    /// Weights run to tens of gigabytes, so a download ends long after anyone
    /// is still watching the Models list — the same reason renders notify.
    func downloadFinished(name: String, bytes: Int64) {
        post(id: "download-" + name, title: loc("notify.download.finished.title"),
             subtitle: name, body: bytes > 0 ? Format.bytes(bytes) : "",
             userInfo: ["section": "models"], after: nil)
    }

    func downloadFailed(name: String, message: String?) {
        post(id: "download-" + name, title: loc("notify.download.failed.title"),
             subtitle: name, body: message ?? "",
             userInfo: ["section": "models"], after: nil)
    }

    private func post(job: RenderJob, title: String, body: String) {
        // The prompt, so two renders finishing an hour apart are told apart. It
        // is the whole prompt now, which can run to a paragraph, and a
        // notification that long is unreadable — so it is cut here rather than
        // left to the system, which would drop the end without saying so.
        post(id: job.id.uuidString, title: title,
             subtitle: String(job.title.prefix(80)), body: body,
             userInfo: ["jobID": job.id.uuidString, "state": job.state.rawValue],
             after: nil)
    }

    private func post(id: String, title: String, subtitle: String, body: String,
                      userInfo: [String: String], after seconds: TimeInterval?) {
        guard isAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        // Deliberately the default interruption level. .timeSensitive would let
        // these through a Focus, and on the merits they qualify — a render the
        // user started and walked away from is exactly the case for it — but it
        // needs a restricted entitlement that Apple has to enable per App ID,
        // and without one the level is silently downgraded. Declaring an
        // entitlement that never takes effect is worse than not claiming it:
        // the code reads as though Focus is handled when it is not. The Focus
        // behaviour is explained in Settings instead, where the user can act on
        // it by allowing Halation inside their Focus.
        content.userInfo = userInfo

        // A nil trigger means deliver now.
        let trigger = seconds.map {
            UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false)
        }
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) {
                // Ignoring this is how the feature came to look silently
                // broken: add() reports refusal here rather than throwing.
                if let error = $0 { Self.log("add failed: \(error)") }
            }
    }

    /// Diagnostics to stderr, on only when the debug menu is.
    ///
    /// Every failure in this file is silent by design of the API: add() hands
    /// back an error rather than throwing, and a notification that is accepted
    /// and then dropped by the system reports nothing at all. Without somewhere
    /// to look, "no notification appeared" has no way to become a cause.
    nonisolated static func log(_ message: String) {
        guard AppDebug.isEnabled else { return }
        FileHandle.standardError.write(Data("[Notifier] \(message)\n".utf8))
    }

    nonisolated func log(_ message: String) { Self.log(message) }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the banner even when Halation is frontmost — see the note above.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let state = (info["state"] as? String).flatMap(RenderJob.State.init(rawValue:))
        let isDownload = info["section"] as? String == "models"
        await MainActor.run {
            NSApplication.shared.activate(ignoringOtherApps: true)
            if isDownload {
                onOpenDownloads?()
            } else {
                onOpen?(state ?? .finished)
            }
        }
    }
}
