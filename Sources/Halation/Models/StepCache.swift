import Foundation

/// Reusing a denoising step's result instead of recomputing it.
///
/// Not a MiniMax feature. H3's model card describes no caching mode; these are
/// ComfyUI's own, in `comfy_extras/nodes_easycache.py`, and they are generic —
/// they wrap any model's sampling and watch how far a step's output has moved
/// since the last one. When it has barely moved, the previous result stands in
/// and that forward pass never runs.
///
/// That is time bought with quality, and H3 is reported to be sensitive to it.
/// Nobody has tuned either implementation for this model, so the thresholds
/// below are ComfyUI's defaults rather than anything measured here. It is
/// offered for previews — seeing the shape of a clip in a fraction of the time —
/// and both are marked experimental upstream.
///
/// The saving scales with the step count, because the first 15% of the schedule
/// always computes in full. At 4 turbo steps there is nothing to reuse; at 30 or
/// 60 there is.
///
/// ComfyUI only. MLX's denoise loop lives in the sidecar package rather than in
/// this app, and patching someone else's package is a patch to carry forever.
enum StepCache: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Every step computed. The reference path.
    case off
    /// ComfyUI's EasyCache.
    case easyCache = "easycache"
    /// ComfyUI's LazyCache: simpler, generally worse, but compatible with
    /// everything, which is why it exists alongside the other.
    case lazyCache = "lazycache"

    var id: String { rawValue }

    /// Node names, so they match what ComfyUI and its documentation call these.
    var label: String {
        switch self {
        case .off: loc("sampling.cache.off")
        case .easyCache: "EasyCache"
        case .lazyCache: "LazyCache"
        }
    }

    var detail: String {
        switch self {
        case .off: loc("sampling.cache.off.detail")
        case .easyCache: loc("sampling.cache.easy.detail")
        case .lazyCache: loc("sampling.cache.lazy.detail")
        }
    }

    /// The ComfyUI node that applies it, or `nil` for the reference path.
    var comfyClassType: String? {
        switch self {
        case .off: nil
        case .easyCache: "EasyCache"
        case .lazyCache: "LazyCache"
        }
    }

    /// ComfyUI's own defaults for both nodes, which agree with each other.
    /// Named rather than written into the graph so the numbers can be found.
    enum Defaults {
        static let reuseThreshold = 0.2
        static let startPercent = 0.15
        static let endPercent = 0.95
    }
}
