import AVFoundation
import CoreImage
import Foundation
import VideoToolbox

/// Converts the sidecar's raw render into the delivery format the user asked for.
///
/// H3 writes a 24 fps, 768 px-short-edge file. Everything here is a re-encode on top
/// of that: codec change, upscale, frame-rate conform, and the optional WAV sidecar.
/// HEVC and H.264 both hit the hardware encoder on Apple silicon.
struct VideoPostProcessor: Sendable {

    struct Result: Sendable {
        var videoURL: URL
        var audioURL: URL?
        var thumbnailURL: URL?
    }

    enum PostProcessError: LocalizedError {
        case noVideoTrack
        case writerFailed(String)
        case readerFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: "The generated file has no video track."
            case .writerFailed(let reason): "Could not write the output video: \(reason)"
            case .readerFailed(let reason): "Could not read the generated video: \(reason)"
            case .cancelled: "Encoding was cancelled."
            }
        }
    }

    var format: OutputFormat

    /// - Parameters:
    ///   - source: the file the sidecar produced.
    ///   - destination: final path, extension already matching `format.codec`.
    func process(source: URL,
                 destination: URL,
                 progress: (@Sendable (Double) -> Void)? = nil) async throws -> Result {
        let asset = AVURLAsset(url: source)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { throw PostProcessError.noVideoTrack }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first

        // Skip the encoder only when the source is *already* what was asked for.
        //
        // This used to test the requested format alone, which silently produced
        // H.264 whenever HEVC was requested: both backends write H.264, so the
        // "nothing to change" path copied the file and the recorded codec lied.
        let sourceCodec = await Self.codec(of: videoTrack)
        let matchesRequest = sourceCodec == format.codec
        if format.needsNoResample, matchesRequest,
           source.pathExtension.lowercased() == destination.pathExtension.lowercased() {
            try replaceItem(at: destination, with: source)
            let audio = format.audio.writesSidecarWAV && audioTrack != nil
                ? try await extractWAV(from: asset, next: destination) : nil
            return Result(videoURL: destination,
                          audioURL: audio,
                          thumbnailURL: try? await makeThumbnail(asset: asset, next: destination))
        }

        try await transcode(asset: asset,
                            videoTrack: videoTrack,
                            audioTrack: audioTrack,
                            destination: destination,
                            progress: progress)

        let audio = format.audio.writesSidecarWAV && audioTrack != nil
            ? try await extractWAV(from: asset, next: destination) : nil

        return Result(videoURL: destination,
                      audioURL: audio,
                      thumbnailURL: try? await makeThumbnail(asset: asset, next: destination))
    }

    /// The codec a track is actually encoded with, or `nil` if unrecognised.
    static func codec(of track: AVAssetTrack) async -> VideoCodec? {
        guard let descriptions = try? await track.load(.formatDescriptions),
              let description = descriptions.first else { return nil }
        switch CMFormatDescriptionGetMediaSubType(description) {
        // 'hvc1' and 'hev1' are the two HEVC sample entries.
        case kCMVideoCodecType_HEVC: return .hevc
        case kCMVideoCodecType_H264: return .h264
        case kCMVideoCodecType_AppleProRes422, kCMVideoCodecType_AppleProRes422HQ,
             kCMVideoCodecType_AppleProRes422LT, kCMVideoCodecType_AppleProRes422Proxy:
            return .proRes422
        default: return nil
        }
    }

    // MARK: - Transcode

    private func transcode(asset: AVURLAsset,
                           videoTrack: AVAssetTrack,
                           audioTrack: AVAssetTrack?,
                           destination: URL,
                           progress: (@Sendable (Double) -> Void)?) async throws {
        let fileType: AVFileType = format.codec == .proRes422 ? .mov : .mp4
        try? FileManager.default.removeItem(at: destination)

        let reader: AVAssetReader
        let writer: AVAssetWriter
        do {
            reader = try AVAssetReader(asset: asset)
            writer = try AVAssetWriter(outputURL: destination, fileType: fileType)
        } catch {
            throw PostProcessError.writerFailed(error.localizedDescription)
        }

        // ── Video ────────────────────────────────────────────────────────────
        let readerVideoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String:
                                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
        readerVideoOutput.alwaysCopiesSampleData = false
        reader.add(readerVideoOutput)

        let size = format.deliverySize
        let writerVideoInput = AVAssetWriterInput(
            mediaType: .video, outputSettings: videoSettings(size: size))
        writerVideoInput.expectsMediaDataInRealTime = false
        // HEVC in an .mp4 needs the 'hvc1' tag to play in QuickTime and Photos.
        if format.codec == .hevc { writerVideoInput.mediaTimeScale = 600 }
        writer.add(writerVideoInput)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerVideoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ])

        // ── Audio ────────────────────────────────────────────────────────────
        var readerAudioOutput: AVAssetReaderTrackOutput?
        var writerAudioInput: AVAssetWriterInput?
        if let audioTrack {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false,
            ])
            reader.add(output)
            readerAudioOutput = output

            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings())
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            writerAudioInput = input
        }

        guard reader.startReading() else {
            throw PostProcessError.readerFailed(reader.error?.localizedDescription ?? "unknown")
        }
        guard writer.startWriting() else {
            throw PostProcessError.writerFailed(writer.error?.localizedDescription ?? "unknown")
        }
        writer.startSession(atSourceTime: .zero)

        let duration = try await asset.load(.duration)

        // Video is retimed and scaled on one queue; audio is a straight copy on
        // another. Both pumps are driven from a single non-isolated region so the
        // AVFoundation objects, none of which are Sendable, never cross a boundary.
        let videoChannel = VideoPumpChannel(readerOutput: readerVideoOutput,
                                            writerInput: writerVideoInput,
                                            adaptor: adaptor)
        let audioChannel = zip(readerAudioOutput, writerAudioInput)
            .map(AudioPumpChannel.init(readerOutput:writerInput:))

        try await pump(video: videoChannel,
                       audio: audioChannel,
                       plan: EncodePlan(targetSize: size,
                                        duration: duration,
                                        frameRate: Int32(format.frameRate.rawValue)),
                       progress: progress)

        await writer.finishWriting()
        if writer.status == .failed {
            throw PostProcessError.writerFailed(writer.error?.localizedDescription ?? "unknown")
        }
        if reader.status == .failed {
            throw PostProcessError.readerFailed(reader.error?.localizedDescription ?? "unknown")
        }
    }

    /// Drives both writer inputs to completion.
    ///
    /// H3 only produces 24 fps. For a higher target we hold each source frame until
    /// the next one is due, which duplicates frames rather than inventing motion —
    /// exactly what the UI promises.
    private func pump(video: VideoPumpChannel,
                      audio: AudioPumpChannel?,
                      plan: EncodePlan,
                      progress: (@Sendable (Double) -> Void)?) async throws {
        let targetSize = plan.targetSize
        let frameDuration = CMTime(value: 1, timescale: plan.frameRate)
        let totalSeconds = max(plan.duration.seconds, 0.001)
        let context = CIContext(options: [.useSoftwareRenderer: false])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let state = EncodeState()
            let group = DispatchGroup()

            // ── Video ────────────────────────────────────────────────────────
            group.enter()
            let videoQueue = DispatchQueue(label: "videogen.encode.video", qos: .userInitiated)
            video.writerInput.requestMediaDataWhenReady(on: videoQueue) {
                while video.writerInput.isReadyForMoreMediaData {
                    guard let sample = state.takePending() ?? video.readerOutput.copyNextSampleBuffer() else {
                        video.writerInput.markAsFinished()
                        progress?(1)
                        state.finishVideo(group)
                        return
                    }

                    let sourceTime = CMSampleBufferGetPresentationTimeStamp(sample)
                    let nextTarget = CMTimeMultiply(frameDuration, multiplier: Int32(state.frameIndex))

                    // The source frame is still in the future: repeat the previous
                    // frame to fill the gap on the denser timeline.
                    if CMTimeCompare(sourceTime, nextTarget) > 0, let previous = state.lastPixelBuffer {
                        if video.adaptor.append(previous, withPresentationTime: nextTarget) {
                            state.frameIndex += 1
                            state.setPending(sample)
                            continue
                        }
                    }

                    guard let source = CMSampleBufferGetImageBuffer(sample) else { continue }
                    guard let scaled = Self.scale(source, to: targetSize,
                                                  pool: video.adaptor.pixelBufferPool,
                                                  context: context) else { continue }

                    if !video.adaptor.append(scaled, withPresentationTime: nextTarget) {
                        state.failure = PostProcessError.writerFailed(
                            "The encoder rejected a frame at \(nextTarget.seconds)s.")
                        video.writerInput.markAsFinished()
                        state.finishVideo(group)
                        return
                    }
                    state.lastPixelBuffer = scaled
                    state.frameIndex += 1
                    progress?(min(1, nextTarget.seconds / totalSeconds))
                }
            }

            // ── Audio ────────────────────────────────────────────────────────
            if let audio {
                group.enter()
                let audioQueue = DispatchQueue(label: "videogen.encode.audio", qos: .userInitiated)
                audio.writerInput.requestMediaDataWhenReady(on: audioQueue) {
                    while audio.writerInput.isReadyForMoreMediaData {
                        guard let sample = audio.readerOutput.copyNextSampleBuffer(),
                              audio.writerInput.append(sample) else {
                            audio.writerInput.markAsFinished()
                            state.finishAudio(group)
                            return
                        }
                    }
                }
            }

            group.notify(queue: .global(qos: .userInitiated)) {
                if let failure = state.failure {
                    continuation.resume(throwing: failure)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Lanczos-quality scale via Core Image, reusing the writer's own buffer pool.
    private static func scale(_ source: CVPixelBuffer,
                              to size: PixelSize,
                              pool: CVPixelBufferPool?,
                              context: CIContext) -> CVPixelBuffer? {
        let sourceWidth = CVPixelBufferGetWidth(source)
        let sourceHeight = CVPixelBufferGetHeight(source)
        if sourceWidth == size.width, sourceHeight == size.height { return source }

        var destination: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &destination)
        }
        if destination == nil {
            CVPixelBufferCreate(nil, size.width, size.height,
                                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                [kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary,
                                &destination)
        }
        guard let destination else { return nil }

        let image = CIImage(cvPixelBuffer: source)
            .transformed(by: CGAffineTransform(scaleX: CGFloat(size.width) / CGFloat(sourceWidth),
                                               y: CGFloat(size.height) / CGFloat(sourceHeight)))
        context.render(image, to: destination)
        return destination
    }
}

/// The geometry and timing one encode pass needs, kept together so the pump takes
/// a handful of arguments rather than a parameter list nobody can read.
private struct EncodePlan: Sendable {
    let targetSize: PixelSize
    let duration: CMTime
    let frameRate: Int32
}

/// Pairs two optionals, or nothing. Keeps the optional audio channel readable at
/// the call site.
private func zip<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
    guard let first, let second else { return nil }
    return (first, second)
}

/// Carries one encode pass's AVFoundation objects across the `@Sendable` boundary
/// that `requestMediaDataWhenReady(on:)` imposes.
///
/// None of these types are `Sendable` and none can be made so. The safety argument
/// is the queue: AVFoundation invokes the block serially on the queue we hand it,
/// and each object is touched only from inside its own block, never from the actor
/// that created it. Asserting that once here is better than repeating an
/// unexplained warning at every capture site.
private struct VideoPumpChannel: @unchecked Sendable {
    let readerOutput: AVAssetReaderTrackOutput
    let writerInput: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
}

/// The audio equivalent of `VideoPumpChannel`; the same reasoning applies.
private struct AudioPumpChannel: @unchecked Sendable {
    let readerOutput: AVAssetReaderTrackOutput
    let writerInput: AVAssetWriterInput
}

/// Mutable state for the encode pump. `requestMediaDataWhenReady` re-enters on a
/// serial queue, so a plain reference box is sufficient and avoids actor hops on a
/// per-frame path.
private final class EncodeState: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: CMSampleBuffer?
    private var videoFinished = false
    private var audioFinished = false

    var frameIndex: Int = 0
    var lastPixelBuffer: CVPixelBuffer?
    var failure: Error?

    /// A frame pulled from the reader but not yet placed, because the output
    /// timeline had not caught up to it.
    func setPending(_ sample: CMSampleBuffer) {
        lock.lock(); defer { lock.unlock() }
        pending = sample
    }

    func takePending() -> CMSampleBuffer? {
        lock.lock(); defer { lock.unlock() }
        defer { pending = nil }
        return pending
    }

    /// `requestMediaDataWhenReady` can re-enter after `markAsFinished`, so each
    /// input leaves the dispatch group exactly once.
    func finishVideo(_ group: DispatchGroup) {
        lock.lock()
        let alreadyDone = videoFinished
        videoFinished = true
        lock.unlock()
        if !alreadyDone { group.leave() }
    }

    func finishAudio(_ group: DispatchGroup) {
        lock.lock()
        let alreadyDone = audioFinished
        audioFinished = true
        lock.unlock()
        if !alreadyDone { group.leave() }
    }
}
