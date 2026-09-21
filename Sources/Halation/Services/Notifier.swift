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
/// Nothing here forces a banner while the app is in front. macOS suppresses
/// foreground notifications unless a delegate opts in, and that default is the
/// behaviour we want: if the window is visible the queue already shows the
/// state, and a banner on top of it is noise.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Called when a render notification is clicked, with the state it reported.
    /// Set by the app, which knows how to bring the right section forward.
    var onOpen: ((RenderJob.State) -> Void)?
    /// Called when a download notification is clicked.
    var onOpenDownloads: (() -> Void)?

    private var askedForPermission = false

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
        guard isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asked once, when the user first queues something.
    func requestPermissionIfNeeded() {
        guard isAvailable, !askedForPermission else { return }
        askedForPermission = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
    func postTestNotifications(after seconds: TimeInterval = 5) {
        post(id: UUID().uuidString, title: loc("notify.finished.title"),
             subtitle: "A test render", body: loc("queue.took", Format.duration(4_231)),
             userInfo: ["state": RenderJob.State.finished.rawValue], after: seconds)
        post(id: UUID().uuidString, title: loc("notify.failed.title"),
             subtitle: "A test render", body: loc("notify.failed.body"),
             userInfo: ["state": RenderJob.State.failed.rawValue], after: seconds + 1)
        post(id: UUID().uuidString, title: loc("notify.download.finished.title"),
             subtitle: "A test model", body: Format.bytes(67 * 1_073_741_824),
             userInfo: ["section": "models"], after: seconds + 2)
        post(id: UUID().uuidString, title: loc("notify.download.failed.title"),
             subtitle: "A test model", body: "The network connection was lost.",
             userInfo: ["section": "models"], after: seconds + 3)
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
        content.userInfo = userInfo

        // A nil trigger means deliver now.
        let trigger = seconds.map {
            UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false)
        }
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - UNUserNotificationCenterDelegate

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
