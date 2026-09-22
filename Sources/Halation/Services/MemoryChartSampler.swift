import Foundation
import Observation

/// One sample a second, kept in a ring long enough to fill the widest window.
///
/// Shared rather than owned by the view so the history survives a trip to
/// Compose and back — a chart that resets whenever you look away is not a
/// history. Sampling starts the first time the chart appears and then continues,
/// which costs a few syscalls a second; it is not started at launch because a
/// session that never opens the Queue should not pay for it at all.
@MainActor
@Observable
final class MemoryChartSampler {
    static let shared = MemoryChartSampler()

    /// Oldest first, so the newest column is the last element.
    private(set) var history: [MemorySample] = []

    /// Wide enough for a full-screen window on the largest display, with room to
    /// spare. At 1 Hz this is twenty minutes of history in a few kilobytes.
    private let capacity = 1200

    private var isRunning = false

    /// Set once by the app so the sampler can ask ComfyUI what Torch is holding.
    /// Weak, and optional: with no runtime attached the Metal band simply falls
    /// back to whatever MLX last reported.
    weak var comfyRuntime: ComfyUIRuntime?

    private init() {}

    /// Idempotent: the chart calls this from `.task` every time it appears, and
    /// only the first call starts the loop.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        Task { [weak self] in
            while true {
                guard let self else { return }
                // ComfyUI answers while it renders, so this is a live figure.
                // MLX cannot, and has pushed its own into the store instead.
                if let polled = await self.comfyRuntime?.metalBytes() {
                    EngineMetalMemory.record(polled)
                }
                self.append(SystemMemoryProbe.sample(engineMetal: EngineMetalMemory.current))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func append(_ sample: MemorySample) {
        history.append(sample)
        if history.count > capacity {
            history.removeFirst(history.count - capacity)
        }
    }
}
