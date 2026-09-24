import Foundation

/// MiniMax H3 is trained on a fixed canvas: 24 fps, 768 px short edge, 4–15 s.
/// Everything the user can pick is either *native* (the model produces it directly)
/// or *conformed* (we re-encode after generation). We never offer a combination the
/// model cannot actually produce.
enum AspectRatio: String, CaseIterable, Codable, Sendable, Identifiable {
    case ultrawide = "21:9"
    case widescreen = "16:9"
    case classic = "4:3"
    case square = "1:1"
    case portraitClassic = "3:4"
    case portrait = "9:16"

    var id: String { rawValue }
    var label: String { rawValue }

    /// The canvas the model resolves this ratio to at its native short edge.
    ///
    /// Mirrors `resolve_canvas_size` in the MLX port: start from a 768 px short
    /// edge, cap the area at 768 × 1344, then round both axes to a multiple of 32.
    /// The cap is why 21:9 comes out below 768 on its short edge.
    var nativeSize: PixelSize { size(shortEdge: Int(Self.shortEdgeTarget)) }

    /// The canvas this ratio resolves to at any short edge.
    ///
    /// The same rule at a smaller scale: the area cap shrinks with the square of
    /// the short edge, so a 21:9 preview is clipped in the same proportion a
    /// 21:9 native render is, and every tier of the same ratio is the same
    /// picture at a different size.
    func size(shortEdge: Int) -> PixelSize {
        Self.resolveCanvas(width: ratioWidth, height: ratioHeight,
                           shortEdge: Double(shortEdge))
    }

    /// The integer pair the pipeline's `aspect` argument expects.
    var aspectPair: (width: Int, height: Int) { (Int(ratioWidth), Int(ratioHeight)) }

    private var ratioWidth: Double {
        switch self {
        case .ultrawide: 21
        case .widescreen: 16
        case .classic: 4
        case .square: 1
        case .portraitClassic: 3
        case .portrait: 9
        }
    }

    private var ratioHeight: Double {
        switch self {
        case .ultrawide: 9
        case .widescreen: 9
        case .classic: 3
        case .square: 1
        case .portraitClassic: 4
        case .portrait: 16
        }
    }

    static let shortEdgeTarget = 768.0
    static let areaBudget = 768.0 * 1344.0

    static func resolveCanvas(width aspectWidth: Double, height aspectHeight: Double,
                              shortEdge: Double = shortEdgeTarget) -> PixelSize {
        let ratio = aspectWidth / aspectHeight
        var height: Double
        var width: Double
        if ratio >= 1 {
            height = shortEdge
            width = shortEdge * ratio
        } else {
            width = shortEdge
            height = shortEdge / ratio
        }
        // Area scales with the square of the short edge, so the cap has to as
        // well. A fixed cap would leave every tier below native uncapped, and
        // the widest ratios would change shape on the way down.
        let scaleFromNative = shortEdge / shortEdgeTarget
        let budget = areaBudget * scaleFromNative * scaleFromNative
        let area = width * height
        if area > budget {
            let scale = (budget / area).squareRoot()
            width *= scale
            height *= scale
        }
        func round32(_ value: Double) -> Int { max(32, Int((value / 32).rounded()) * 32) }
        return PixelSize(width: round32(width), height: round32(height))
    }

    var isPortrait: Bool { nativeSize.height > nativeSize.width }

    var symbolName: String {
        switch self {
        case .ultrawide, .widescreen: "rectangle"
        case .classic:                "rectangle.ratio.4.to.3"
        case .square:                 "square"
        case .portraitClassic:        "rectangle.ratio.3.to.4"
        case .portrait:               "rectangle.portrait"
        }
    }
}

struct PixelSize: Codable, Sendable, Hashable, CustomStringConvertible {
    var width: Int
    var height: Int
    var description: String { "\(width)×\(height)" }

    var pixelCount: Int { width * height }

    /// Scales the canvas so the short edge hits `shortEdge`, keeping both
    /// dimensions even (required by every block-based video codec).
    func scaled(toShortEdge shortEdge: Int) -> PixelSize {
        let currentShort = min(width, height)
        guard currentShort > 0, shortEdge != currentShort else { return self }
        let factor = Double(shortEdge) / Double(currentShort)
        func even(_ value: Double) -> Int { max(2, Int((value / 2.0).rounded()) * 2) }
        return PixelSize(width: even(Double(width) * factor),
                         height: even(Double(height) * factor))
    }
}

/// Delivery resolution, and — below native — generation resolution too.
///
/// Above 768 nothing local adds detail. H3's 2K mode (H3-Regenerate-2K) is
/// explicitly *not* open-sourced — MiniMax run it as a cloud API — so every tier
/// above native is a plain resample that adds pixels, not detail. The UI says so
/// rather than implying a quality gain.
///
/// Below 768 is the opposite: the model really does render at that size. The MLX
/// port takes `height`/`width` overrides at any multiple of 32, and ComfyUI's H3
/// nodes take the canvas directly, so a preview tier produces a smaller latent
/// grid rather than a downscale of a full render. That is where the time goes —
/// cost follows the packed sequence, which is quadratic in it for attention, so
/// halving the short edge is worth more than halving the work.
///
/// What it costs is fidelity. H3 is trained at a 768 px short edge, so a preview
/// is off-distribution and will drift from what a full render of the same seed
/// gives. It is for seeing whether a shot works, not for seeing how it will look.
enum ResolutionTier: String, CaseIterable, Codable, Sendable, Identifiable {
    case preview256 = "256"
    case preview384 = "384"
    case preview512 = "512"
    case preview640 = "640"
    case native768 = "768"
    case upscale1080 = "1080"
    case upscale1440 = "1440"

    var id: String { rawValue }

    /// Ascending, so the picker reads as one ladder from cheapest to largest
    /// rather than as two lists that happen to meet at native.
    var shortEdge: Int {
        switch self {
        case .preview256: 256
        case .preview384: 384
        case .preview512: 512
        case .preview640: 640
        case .native768: 768
        case .upscale1080: 1080
        case .upscale1440: 1440
        }
    }

    /// The short edge the model is actually asked for. Above native the model
    /// still renders at native and the extra pixels are added afterwards.
    var generationShortEdge: Int { min(shortEdge, Int(AspectRatio.shortEdgeTarget)) }

    var label: String {
        switch self {
        case .native768: loc("format.res.native")
        case .upscale1080: loc("format.res.1080")
        case .upscale1440: loc("format.res.1440")
        // One format string rather than four near-identical ones: the number is
        // the only thing that differs, and four copies of a sentence is four
        // chances for them to drift apart in ten languages.
        default: loc("format.res.preview", rawValue)
        }
    }

    var detail: String {
        switch self {
        case .native768: loc("format.res.native.detail")
        case .upscale1080: loc("format.res.1080.detail")
        case .upscale1440: loc("format.res.1440.detail")
        default: loc("format.res.preview.detail")
        }
    }

    var isUpscale: Bool { shortEdge > Int(AspectRatio.shortEdgeTarget) }
    /// Below native: rendered small, not shrunk afterwards.
    var isPreview: Bool { shortEdge < Int(AspectRatio.shortEdgeTarget) }
}

/// H3 only ever emits 24 fps. Higher rates are conform-only: we duplicate frames
/// on a fixed cadence. We label that plainly instead of implying interpolation.
enum FrameRate: Int, CaseIterable, Codable, Sendable, Identifiable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }
    var isNative: Bool { self == .fps24 }

    var label: String {
        isNative ? loc("format.fps.native") : loc("format.fps.conformed", "\(rawValue)")
    }

    var detail: String {
        switch self {
        case .fps24: loc("format.fps.native.detail")
        case .fps30: loc("format.fps.30.detail")
        case .fps60: loc("format.fps.60.detail")
        }
    }
}

/// Delivery codec.
///
/// The list is what the backends actually emit, not what AVFoundation could
/// produce. Both write H.264 at the point of generation, so choosing it means the
/// file is delivered exactly as rendered — no second encode, no lost generation.
///
/// Both are written at the point of generation — ComfyUI through its SaveVideo
/// node, MLX through the sidecar's own ffmpeg call — so neither involves a
/// re-encode.
///
/// HEVC is deliberately absent. Neither engine writes it, so asking for it would
/// mean re-encoding the H.264 output: quality spent to change container. If that
/// trade is ever wanted it is a small change, and `hevc_videotoolbox` exists here.
enum VideoCodec: String, CaseIterable, Sendable, Identifiable {
    case h264
    case av1

    var id: String { rawValue }

    var label: String {
        switch self {
        case .h264: "H.264"
        case .av1: "AV1"
        }
    }

    var detail: String {
        switch self {
        case .h264: loc("format.codec.h264.detail")
        case .av1: loc("format.codec.av1.detail")
        }
    }

    /// The identifier ComfyUI's SaveVideo node expects.
    var comfyUIName: String { rawValue }

    var fileExtension: String { "mp4" }

    /// Bits per pixel per second, for a sane default when we do have to re-encode.
    var bitsPerPixel: Double {
        switch self {
        case .h264: 0.12
        case .av1: 0.06
        }
    }
}

/// Old library entries recorded codecs that no longer exist (`hevc`, `proRes422`).
/// Decode them as H.264 rather than failing to read the index at all.
extension VideoCodec: Codable {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VideoCodec(rawValue: raw) ?? .h264
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum AudioHandling: String, CaseIterable, Codable, Sendable, Identifiable {
    case muxed
    case muxedPlusWAV

    var id: String { rawValue }

    var label: String {
        switch self {
        case .muxed: loc("format.audio.muxed")
        case .muxedPlusWAV: loc("format.audio.wav")
        }
    }

    var writesSidecarWAV: Bool { self == .muxedPlusWAV }
}

/// The complete, validated description of what we are asked to deliver.
struct OutputFormat: Codable, Sendable, Hashable {
    var aspectRatio: AspectRatio = .widescreen
    var resolution: ResolutionTier = .native768
    var frameRate: FrameRate = .fps24
    var codec: VideoCodec = .h264
    var audio: AudioHandling = .muxed

    /// The canvas the model is asked to render.
    var generationSize: PixelSize {
        aspectRatio.size(shortEdge: resolution.generationShortEdge)
    }

    /// The canvas we finally write to disk.
    ///
    /// Only an upscale changes it. A preview is delivered at the size it was
    /// rendered — resampling it back up to native would add nothing but time
    /// and a false impression of what the model produced.
    var deliverySize: PixelSize {
        resolution.isUpscale
            ? generationSize.scaled(toShortEdge: resolution.shortEdge)
            : generationSize
    }

    /// True when the *delivery* settings ask for no geometry or timing change.
    ///
    /// Not sufficient on its own to skip the encoder: the source's codec has to
    /// match the requested one as well. See `VideoPostProcessor.process`.
    /// A preview needs no resample either: it is delivered at the size it was
    /// rendered. Testing for native exactly would have sent every preview
    /// through the encoder for nothing — a lost generation of quality and time
    /// spent, on the one setting whose whole purpose is to be quick.
    var needsNoResample: Bool {
        !resolution.isUpscale && frameRate.isNative
    }

    func estimatedBitrate() -> Int? {
        guard codec.bitsPerPixel > 0 else { return nil }
        let size = deliverySize
        let raw = Double(size.width * size.height) * Double(frameRate.rawValue) * codec.bitsPerPixel
        return Int(raw.rounded())
    }
}

/// The model's temporal grid.
///
/// H3 runs at a fixed 24 fps and the video VAE only encodes frame counts of the
/// form `17n + 5`, so a requested duration is snapped before rendering. The UI
/// shows the snapped value rather than pretending the slider is exact.
enum FrameGrid {
    static let fps = 24

    /// The port snaps a requested duration *up* to the next grid point, so we round
    /// up here too rather than to the nearest — otherwise our estimates and the
    /// recorded metadata would disagree with what actually rendered.
    static func alignedFrameCount(forSeconds seconds: Int) -> Int {
        let requested = seconds * fps
        let n = max(0, ((Double(requested) - 5.0) / 17.0).rounded(.up))
        return Int(n) * 17 + 5
    }

    /// True when the request happens to land exactly on the grid. Only 8 seconds
    /// does, between 5 and 15: the grid repeats against 24 fps every 24 steps.
    static func isExact(forSeconds seconds: Int) -> Bool {
        alignedFrameCount(forSeconds: seconds) == seconds * fps
    }

    static func alignedSeconds(forSeconds seconds: Int) -> Double {
        Double(alignedFrameCount(forSeconds: seconds)) / Double(fps)
    }
}
