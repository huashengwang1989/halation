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

    /// The canvas the model resolves this ratio to.
    ///
    /// Mirrors `resolve_canvas_size` in the MLX port: start from a 768 px short
    /// edge, cap the area at 768 × 1344, then round both axes to a multiple of 32.
    /// The cap is why 21:9 comes out below 768 on its short edge.
    var nativeSize: PixelSize { Self.resolveCanvas(width: ratioWidth, height: ratioHeight) }

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

    static func resolveCanvas(width aspectWidth: Double, height aspectHeight: Double) -> PixelSize {
        let ratio = aspectWidth / aspectHeight
        var height: Double
        var width: Double
        if ratio >= 1 {
            height = shortEdgeTarget
            width = shortEdgeTarget * ratio
        } else {
            width = shortEdgeTarget
            height = shortEdgeTarget / ratio
        }
        let area = width * height
        if area > areaBudget {
            let scale = (areaBudget / area).squareRoot()
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

/// Delivery resolution.
///
/// H3 renders at a 768 px short edge and nothing local can change that. Its 2K mode
/// (H3-Regenerate-2K) is explicitly *not* open-sourced — MiniMax run it as a cloud
/// API — so every tier above native here is a plain resample that adds pixels, not
/// detail. The UI says so rather than implying a quality gain.
enum ResolutionTier: String, CaseIterable, Codable, Sendable, Identifiable {
    case native768 = "768"
    case upscale1080 = "1080"
    case upscale1440 = "1440"

    var id: String { rawValue }

    var shortEdge: Int {
        switch self {
        case .native768: 768
        case .upscale1080: 1080
        case .upscale1440: 1440
        }
    }

    var label: String {
        switch self {
        case .native768: "768p — native"
        case .upscale1080: "1080p — upscaled"
        case .upscale1440: "1440p — upscaled"
        }
    }

    var detail: String {
        switch self {
        case .native768:
            "Exactly what the model produces, with no resampling. Recommended."
        case .upscale1080:
            "Resampled after generation to fit a 1080p delivery pipeline. No detail is added."
        case .upscale1440:
            "Resampled to 1440p. Larger files for the same real detail; useful only if a "
            + "downstream tool demands this size."
        }
    }

    var isUpscale: Bool { self != .native768 }
}

/// H3 only ever emits 24 fps. Higher rates are conform-only: we duplicate frames
/// on a fixed cadence. We label that plainly instead of implying interpolation.
enum FrameRate: Int, CaseIterable, Codable, Sendable, Identifiable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }
    var isNative: Bool { self == .fps24 }

    var label: String { isNative ? "24 fps — native" : "\(rawValue) fps — conformed" }

    var detail: String {
        switch self {
        case .fps24: "The model's own cadence. No frames are invented or dropped."
        case .fps30: "Frames are duplicated to a 30 fps timeline. Motion may judder slightly."
        case .fps60: "Frames are duplicated to a 60 fps timeline. No new motion is synthesised."
        }
    }
}

/// Delivery codec.
///
/// The list is what the backends actually emit, not what AVFoundation could
/// produce. Both write H.264 at the point of generation, so choosing it means the
/// file is delivered exactly as rendered — no second encode, no lost generation.
///
/// HEVC is deliberately absent. Asking for it would mean re-encoding the model's
/// H.264 output, which costs quality to save space; if that trade is ever wanted
/// it is a small change, and `hevc_videotoolbox` is available on this machine.
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
        case .h264:
            "What the model produces. Delivered as rendered, with no second encode, "
            + "and plays everywhere."
        case .av1:
            "Smaller files at the same quality, but this Mac has no AV1 encoder in "
            + "hardware, so it is encoded in software and adds several minutes. "
            + "ComfyUI only."
        }
    }

    /// Whether a backend can write this directly, without a re-encode on our side.
    func isNative(to backend: BackendID) -> Bool {
        switch self {
        case .h264: true
        case .av1: backend == .comfyUI
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
        case .muxed: "Muxed into the video"
        case .muxedPlusWAV: "Muxed, plus a separate WAV"
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
    var generationSize: PixelSize { aspectRatio.nativeSize }

    /// The canvas we finally write to disk.
    var deliverySize: PixelSize {
        resolution == .native768
            ? generationSize
            : generationSize.scaled(toShortEdge: resolution.shortEdge)
    }

    /// True when the *delivery* settings ask for no geometry or timing change.
    ///
    /// Not sufficient on its own to skip the encoder: the source's codec has to
    /// match the requested one as well. See `VideoPostProcessor.process`.
    var needsNoResample: Bool {
        resolution == .native768 && frameRate.isNative
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
