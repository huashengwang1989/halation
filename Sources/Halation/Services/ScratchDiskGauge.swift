import Foundation
import Observation

/// How much of the disk a render is holding, and how close that is to trouble.
///
/// Two consumers, because they are the two that a render grows and that nothing
/// else on the machine accounts for: the swap file, which is where the real
/// gigabytes go — 66 GB measured on a 128 GB Mac mid-render — and the scratch
/// directories, which stay in megabytes. Showing only the second would have
/// been a gauge that never moved while the disk filled.
///
/// Its own bar rather than a band on the memory chart because the two fail
/// differently. Memory that runs out swaps and the render gets slow; disk that
/// runs out stops the render and can take the machine's own headroom with it.
@MainActor
@Observable
final class ScratchDiskGauge {
    static let shared = ScratchDiskGauge()

    struct Reading: Equatable, Sendable {
        /// What the render working files hold, across every place they land.
        var scratch: Int64 = 0
        /// Swap in use. On disk, and the larger of the two by orders of
        /// magnitude during a render.
        var swap: Int64 = 0
        /// What is left on the volume. Already excludes the scratch, because
        /// the scratch is occupying it.
        var free: Int64 = 0
        /// The whole volume, which sets where the warnings sit: 50 GB left is
        /// comfortable on a 4 TB disk and nearly fatal on a 500 GB one.
        var capacity: Int64 = 0

        /// Everything the two consumers could ever occupy: what they hold now
        /// plus what is still free for them to take.
        var total: Int64 { swap + scratch + free }

        var swapFraction: Double { share(of: swap) }
        var scratchFraction: Double { share(of: scratch) }

        /// Both together, which is what the colour is decided on: the disk does
        /// not care which of them filled it.
        var fraction: Double { swapFraction + scratchFraction }

        private func share(of value: Int64) -> Double {
            guard total > 0 else { return 0 }
            return Double(value) / Double(total)
        }
    }

    enum Level {
        case fine, warning, critical

        /// Two tints, one per segment, so the pair reads as one state rather
        /// than as two independent readings. At ease the swap segment borrows
        /// the memory chart's own violet, because it is the same swap.
        var swapTint: Tint {
            switch self {
            case .fine: .violet
            case .warning: .orange
            case .critical: .red
            }
        }

        var scratchTint: Tint {
            switch self {
            case .fine: .green
            case .warning: .yellow
            case .critical: .pink
            }
        }
    }

    /// Named rather than using SwiftUI's `Color` so this file stays free of
    /// the view layer; the bar maps it.
    enum Tint { case violet, green, orange, yellow, red, pink }

    private(set) var reading = Reading()

    private var isRunning = false
    /// Slower than the memory chart on purpose: this needs a directory walk,
    /// and neither swap nor scratch changes in the space of a frame.
    private static let interval: Duration = .seconds(5)

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        Task { [weak self] in
            while true {
                guard self != nil else { return }
                let reading = await Self.measure()
                self?.reading = reading
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    var level: Level {
        let reading = reading
        let percent = reading.fraction * 100
        if percent >= 90 || reading.free <= Self.floor(critical: true, capacity: reading.capacity) {
            return .critical
        }
        if percent >= 75 || reading.free <= Self.floor(critical: false, capacity: reading.capacity) {
            return .warning
        }
        return .fine
    }

    /// How little free space is too little, which depends on the disk.
    ///
    /// Anchored at the two sizes worth naming — 50 GB critical on a 900 GB or
    /// larger disk, 25 GB on a 600 GB or smaller one, and twice each for the
    /// warning — and interpolated between, so a 750 GB disk does not fall off
    /// either end of a rule that only mentions the extremes.
    static func floor(critical: Bool, capacity: Int64) -> Int64 {
        let gigabyte = 1_000_000_000.0
        let low = (critical ? 25.0 : 50.0) * gigabyte
        let high = (critical ? 50.0 : 100.0) * gigabyte
        let small = 600 * gigabyte
        let large = 900 * gigabyte
        let size = Double(capacity)
        if size <= small { return Int64(low) }
        if size >= large { return Int64(high) }
        let t = (size - small) / (large - small)
        return Int64(low + (high - low) * t)
    }

    // MARK: - Measuring

    nonisolated private static func measure() async -> Reading {
        await Task.detached(priority: .utility) {
            var reading = Reading()
            let scratch = RenderEngine.scratchDirectory
            // Both engines' working files, not just the app's own directory.
            // A ComfyUI render writes its video into ComfyUI's output folder
            // first and is fetched from there, so measuring only `scratch`
            // reported a ComfyUI render as using less disk than it does — and
            // the bar is labelled for the work, not for one directory.
            let comfy = ComfyUIRuntime.rootURL
            reading.scratch = directorySize(scratch)
                + directorySize(comfy.appending(path: "output"))
                + directorySize(comfy.appending(path: "temp"))

            // Asked of the scratch directory's own volume rather than assumed
            // to be the boot disk: the models folder can be moved, and one day
            // this might be too.
            reading.swap = SystemMemoryProbe.swapUsedBytes()

            let probe = FileManager.default.fileExists(atPath: scratch.path)
                ? scratch : RuntimeManager.supportDirectory
            if let values = try? probe.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey,
            ]) {
                reading.free = values.volumeAvailableCapacityForImportantUsage ?? 0
                reading.capacity = Int64(values.volumeTotalCapacity ?? 0)
            }
            return reading
        }.value
    }

    nonisolated private static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: [], errorHandler: { _, _ in true })
        else { return 0 }
        var total: Int64 = 0
        for case let item as URL in enumerator {
            let values = try? item.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
