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

        // Nothing to change: keep the model's own bytes rather than re-encoding and
        // losing a generation of quality for no reason.
        if format.isPassthrough, source.pathExtension.lowercased() == destination.pathExtension.lowercased() {
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
        try await pump(readerVideoOutput: readerVideoOutput,
                       writerVideoInput: writerVideoInput,
                       adaptor: adaptor,
                       readerAudioOutput: readerAudioOutput,
                       writerAudioInput: writerAudioInput,
                       targetSize: size,
                       duration: duration,
                       frameRate: Int32(format.frameRate.rawValue),
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
    private func pump(readerVideoOutput: AVAssetReaderTrackOutput,
                      writerVideoInput: AVAssetWriterInput,
                      adaptor: AVAssetWriterInputPixelBufferAdaptor,
                      readerAudioOutput: AVAssetReaderTrackOutput?,
                      writerAudioInput: AVAssetWriterInput?,
                      targetSize: PixelSize,
                      duration: CMTime,
                      frameRate: Int32,
                      progress: (@Sendable (Double) -> Void)?) async throws {
        let frameDuration = CMTime(value: 1, timescale: frameRate)
        let totalSeconds = max(duration.seconds, 0.001)
        let context = CIContext(options: [.useSoftwareRenderer: false])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let state = EncodeState()
            let group = DispatchGroup()

            // ── Video ────────────────────────────────────────────────────────
            group.enter()
            let videoQueue = DispatchQueue(label: "videogen.encode.video", qos: .userInitiated)
            writerVideoInput.requestMediaDataWhenReady(on: videoQueue) {
                while writerVideoInput.isReadyForMoreMediaData {
                    guard let sample = state.takePending() ?? readerVideoOutput.copyNextSampleBuffer() else {
                        writerVideoInput.markAsFinished()
                        progress?(1)
                        state.finishVideo(group)
                        return
                    }

                    let sourceTime = CMSampleBufferGetPresentationTimeStamp(sample)
                    let nextTarget = CMTimeMultiply(frameDuration, multiplier: Int32(state.frameIndex))

                    // The source frame is still in the future: repeat the previous
                    // frame to fill the gap on the denser timeline.
                    if CMTimeCompare(sourceTime, nextTarget) > 0, let previous = state.lastPixelBuffer {
                        if adaptor.append(previous, withPresentationTime: nextTarget) {
                            state.frameIndex += 1
                            state.setPending(sample)
                            continue
                        }
                    }

                    guard let source = CMSampleBufferGetImageBuffer(sample) else { continue }
                    guard let scaled = Self.scale(source, to: targetSize,
                                                  pool: adaptor.pixelBufferPool,
                                                  context: context) else { continue }

                    if !adaptor.append(scaled, withPresentationTime: nextTarget) {
                        state.failure = PostProcessError.writerFailed(
                            "The encoder rejected a frame at \(nextTarget.seconds)s.")
                        writerVideoInput.markAsFinished()
                        state.finishVideo(group)
                        return
                    }
                    state.lastPixelBuffer = scaled
                    state.frameIndex += 1
                    progress?(min(1, nextTarget.seconds / totalSeconds))
                }
            }

            // ── Audio ────────────────────────────────────────────────────────
            if let readerAudioOutput, let writerAudioInput {
                group.enter()
                let audioQueue = DispatchQueue(label: "videogen.encode.audio", qos: .userInitiated)
                writerAudioInput.requestMediaDataWhenReady(on: audioQueue) {
                    while writerAudioInput.isReadyForMoreMediaData {
                        guard let sample = readerAudioOutput.copyNextSampleBuffer(),
                              writerAudioInput.append(sample) else {
                            writerAudioInput.markAsFinished()
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

    // MARK: - Settings

    private func videoSettings(size: PixelSize) -> [String: Any] {
        switch format.codec {
        case .proRes422:
            return [
                AVVideoCodecKey: AVVideoCodecType.proRes422.rawValue,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
            ]
        case .hevc, .h264:
            var compression: [String: Any] = [
                AVVideoAverageBitRateKey: format.estimatedBitrate() ?? 12_000_000,
                AVVideoExpectedSourceFrameRateKey: format.frameRate.rawValue,
                AVVideoMaxKeyFrameIntervalDurationKey: 2.0,
                AVVideoAllowFrameReorderingKey: true,
            ]
            if format.codec == .hevc {
                compression[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel
            } else {
                compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
            }
            return [
                AVVideoCodecKey: (format.codec == .hevc
                                  ? AVVideoCodecType.hevc : AVVideoCodecType.h264).rawValue,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
                AVVideoCompressionPropertiesKey: compression,
            ]
        }
    }

    private func audioSettings() -> [String: Any] {
        if format.codec == .proRes422 {
            // Keep an editing intermediate lossless.
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        }
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 256_000,
        ]
    }

    // MARK: - Extras

    /// Writes the model's audio out on its own, for use in an editor.
    private func extractWAV(from asset: AVAsset, next destination: URL) async throws -> URL? {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let url = destination.deletingPathExtension().appendingPathExtension("wav")
        try? FileManager.default.removeItem(at: url)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)

        let writer = try AVAssetWriter(outputURL: url, fileType: .wav)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        writer.add(input)

        guard reader.startReading(), writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "videogen.encode.wav")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard let sample = output.copyNextSampleBuffer() else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                    if !input.append(sample) {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }

    private func makeThumbnail(asset: AVAsset, next destination: URL) async throws -> URL? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)

        let duration = try await asset.load(.duration)
        // A third of the way in — the first frame is often still resolving.
        let time = CMTimeMultiplyByFloat64(duration, multiplier: 0.33)
        let (image, _) = try await generator.image(at: time)

        let url = destination.deletingPathExtension().appendingPathExtension("jpg")
        guard let destinationRef = CGImageDestinationCreateWithURL(
            url as CFURL, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destinationRef, image,
                                   [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destinationRef) ? url : nil
    }

    private func replaceItem(at destination: URL, with source: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: source, to: destination)
    }
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
