import Foundation

/// The last known figure for what the engine holds on the GPU, and how stale it
/// is.
///
/// Two engines, two very different cadences, which is why this is a store with a
/// timestamp rather than a simple value:
///
/// - **ComfyUI** runs an HTTP server and answers a route while it renders, so
///   this is refreshed every second.
/// - **MLX** is a pipe-based job protocol sitting inside a compute loop. It can
///   only report when it emits an event, which is per *step* — minutes apart on
///   a real render. The figure is right when it arrives and then holds.
///
/// So the band this drives is smooth under ComfyUI and stepped under MLX, and
/// `age` is how a reader tells which they are looking at. Nothing is
/// extrapolated between reports: a stale figure is reported stale rather than
/// guessed forward.
@MainActor
enum EngineMetalMemory {
    private(set) static var bytes: Int64 = 0
    private(set) static var updated: Date?

    /// Anything older than this is treated as gone rather than shown as current.
    /// Generous enough for MLX's per-step cadence on a slow render.
    private static let staleAfter: TimeInterval = 20 * 60

    static var current: Int64 {
        guard let updated, Date().timeIntervalSince(updated) < staleAfter else { return 0 }
        return bytes
    }

    static var age: TimeInterval? {
        updated.map { Date().timeIntervalSince($0) }
    }

    static func record(_ value: Int64) {
        bytes = max(0, value)
        updated = Date()
    }

    /// Called when an engine stops, so the band drops to nothing rather than
    /// leaving a ghost of the last render on the chart.
    static func clear() {
        bytes = 0
        updated = nil
    }
}
