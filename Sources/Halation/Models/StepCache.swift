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
/// Both engines offer it, by different routes. ComfyUI has the two nodes; the
/// MLX port has none, so Halation's own sidecar wraps the port's transformer
/// with a translation of the same EasyCache algorithm. The port itself is left
/// alone — it is cloned from upstream and replaced whenever the runtime is
/// repaired, so a change made in there would have to be made again every time.
enum StepCache: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Every step computed. The reference path.
    case off
    /// ComfyUI's EasyCache.
    case easyCache = "easycache"
    /// ComfyUI's LazyCache: simpler, generally worse, but compatible with
    /// everything, which is why it exists alongside the other.
    case lazyCache = "lazycache"
    /// Halation's own, for MLX: EasyCache's estimate, wrapped around the port's
    /// transformer by the sidecar.
    case reuse

    var id: String { rawValue }

    /// Node names, so they match what ComfyUI and its documentation call these.
    var label: String {
        switch self {
        case .off: loc("sampling.cache.off")
        case .easyCache: "EasyCache"
        case .lazyCache: "LazyCache"
        // Not a node name, because it is not a node: naming it "EasyCache"
        // here would claim this is the same code running, which it is not.
        case .reuse: loc("sampling.cache.on")
        }
    }

    var detail: String {
        switch self {
        case .off: loc("sampling.cache.off.detail")
        case .easyCache: loc("sampling.cache.easy.detail")
        case .lazyCache: loc("sampling.cache.lazy.detail")
        case .reuse: loc("sampling.cache.reuse.detail")
        }
    }

    /// The ComfyUI node that applies it, or `nil` for the reference path.
    var comfyClassType: String? {
        switch self {
        case .off, .reuse: nil
        case .easyCache: "EasyCache"
        case .lazyCache: "LazyCache"
        }
    }

    /// What the MLX sidecar is told. It has one implementation, so this is only
    /// on or off.
    var mlxName: String { self == .off ? "off" : "reuse" }

    /// What each engine can actually do. A spec carrying the other engine's
    /// choice is not an error — it is what happens when someone sets this up on
    /// ComfyUI and then switches to MLX — so `resolved(for:)` translates rather
    /// than refusing.
    static func available(for backend: BackendID) -> [StepCache] {
        switch backend {
        case .comfyUI: [.off, .easyCache, .lazyCache]
        case .mlx: [.off, .reuse]
        }
    }

    /// The nearest equivalent this engine can run. "On" survives the crossing;
    /// which of ComfyUI's two nodes it was does not, because MLX has neither.
    func resolved(for backend: BackendID) -> StepCache {
        let options = Self.available(for: backend)
        if options.contains(self) { return self }
        return self == .off ? .off : (options.first { $0 != .off } ?? .off)
    }

    /// ComfyUI's own defaults for both nodes, which agree with each other.
    /// Named rather than written into the graph so the numbers can be found.
    enum Defaults {
        static let reuseThreshold = 0.2
        static let startPercent = 0.15
        static let endPercent = 0.95
    }
}
