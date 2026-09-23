import Foundation

/// What one sampling step over one megapixel costs on this machine.
///
/// Everything about how long a render takes reduces to this number: steps and
/// pixels are known from the spec, and the rest is the machine. Measuring it
/// beats predicting it, so finished renders are used wherever there are any, and
/// the prediction is only what fills the gap before the first one.
enum RenderThroughput {

    /// Seconds per step per megapixel on an M3 Ultra, at bf16.
    ///
    /// Derived from the one figure the MLX port publishes: bf16, 5 s, 8 steps at
    /// 1344×768 in about 1.2 hours. That is 4320 s over 8 steps and 1.03
    /// megapixels.
    private static let anchor = 523.0
    private static let anchorBandwidth = 800.0

    /// The estimate before this machine has rendered anything.
    ///
    /// Scaled from the anchor by memory bandwidth, which is what these models are
    /// limited by. Coarse on purpose — it is replaced by a measurement as soon as
    /// one render finishes.
    static var predicted: Double {
        anchor * (anchorBandwidth / MachineProfile.memoryBandwidth)
    }

    /// Measured from renders that actually happened here.
    ///
    /// The median rather than the mean: a render that was paused, or that queued
    /// behind a model load, is an outlier that would drag a mean a long way and
    /// moves a median hardly at all.
    ///
    /// Kept per backend, because the two are not comparable — ComfyUI runs a
    /// distilled LoRA at four steps where MLX wants sixteen, so a step means a
    /// different amount of work in each.
    ///
    /// Renders that reused steps are excluded for the same reason. Their cost
    /// is divided by the steps that were asked for rather than the ones that
    /// ran, so one 16-step render that skipped 6 reads as 202 s per step where
    /// the machine actually needs 342 — and every later estimate, cached or
    /// not, would inherit that. How much a cache saves depends on the clip, so
    /// it cannot be corrected for either; the honest sample is the renders that
    /// computed every step.
    static func measured(from items: [LibraryItem], backend: BackendID) -> Double? {
        let samples = items.compactMap { item -> Double? in
            guard let seconds = item.renderSeconds, seconds > 0,
                  item.spec.resolvedBackend == backend,
                  item.spec.sampling.stepCache.resolved(for: backend) == .off
            else { return nil }
            // A render that did not record which checkpoint it used is still a
            // real measurement of this machine. Reference renders are all like
            // this — ComfyUI resolves its own model set — and dropping them left
            // the only engine with timings falling back to a figure published for
            // a different Mac. bf16 is the neutral assumption: no speed-up
            // applied, so an unrecorded quantized run reads slightly slow rather
            // than inventing a correction.
            let quantization = item.spec.transformerEntryID
                .flatMap(ModelCatalog.entry(id:))?.quantization ?? .bf16
            let work = self.work(sampling: item.spec.sampling,
                                 pixels: item.spec.format.generationSize.pixelCount,
                                 quantization: quantization)
            guard work > 0 else { return nil }
            return seconds / work
        }
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let middle = sorted.count / 2
        // Averaged across the two middle values on an even count. Taking the
        // upper one alone biases every estimate high, which shows up immediately
        // when there are only two renders to go on.
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    /// The work a spec asks for, in step-megapixels, normalised for the speed-up a
    /// quantized checkpoint gives. Multiplying this by a throughput gives seconds.
    static func work(sampling: SamplingSettings,
                     pixels: Int,
                     quantization: Quantization) -> Double {
        let megapixels = Double(pixels) / 1_000_000
        let lengthFactor = Double(sampling.durationSeconds) / 5.0
        let speedup: Double = switch quantization {
        case .q4: 1.4
        case .q6: 1.25
        case .q8: 1.1
        default: 1.0
        }
        return Double(sampling.steps) * megapixels * lengthFactor / speedup
    }
}
