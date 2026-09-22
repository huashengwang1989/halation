import Foundation
import Observation

/// How much of the disk the render scratch has taken, and how close that is to
/// being a problem.
///
/// Its own gauge rather than a line in the memory chart because the two fail
/// differently. Memory that runs out swaps and the render gets slow; disk that
/// runs out stops the render and can take the machine's own headroom with it.
@MainActor
@Observable
final class ScratchDiskGauge {
    static let shared = ScratchDiskGauge()

    struct Reading: Equatable, Sendable {
        /// What the scratch directory holds.
        var scratch: Int64 = 0
        /// What is left on the volume. Already excludes the scratch, because
        /// the scratch is occupying it.
        var free: Int64 = 0
        /// The whole volume, which sets where the warnings sit: 50 GB left is
        /// comfortable on a 4 TB disk and nearly fatal on a 500 GB one.
        var capacity: Int64 = 0

        /// Scratch as a share of what the scratch could ever have — itself plus
        /// everything still free. Reaches 100% only when the disk is full.
        var fraction: Double {
            let total = scratch + free
            guard total > 0 else { return 0 }
            return Double(scratch) / Double(total)
        }
    }

    enum Level {
        case fine, warning, critical

        var tint: Color3 {
            switch self {
            case .fine: .green
            case .warning: .orange
            case .critical: .red
            }
        }
    }

    /// Named rather than using SwiftUI's `Color` so this file stays free of
    /// the view layer; the bar maps it.
    enum Color3 { case green, orange, red }

    private(set) var reading = Reading()

    private var isRunning = false
    /// Slower than the memory chart on purpose: this needs a directory walk,
    /// and scratch changes over minutes, not frames.
    private let interval: Duration = .seconds(5)

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        Task { [weak self] in
            while true {
                guard self != nil else { return }
                let reading = await Self.measure()
                self?.reading = reading
                try? await Task.sleep(for: .seconds(5))
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
            reading.scratch = directorySize(scratch)

            // Asked of the scratch directory's own volume rather than assumed
            // to be the boot disk: the models folder can be moved, and one day
            // this might be too.
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
