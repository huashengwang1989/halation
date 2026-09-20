import AVFoundation
import CoreImage
import Foundation
import ImageIO
import VideoToolbox

/// Encoder settings, plus the extras written alongside the video.
///
/// Split from the main file so `VideoPostProcessor.swift` stays about the encode
/// pipeline itself; these are the parameters it hands to AVFoundation and the two
/// companion artefacts (WAV sidecar, poster frame).
extension VideoPostProcessor {

    // MARK: - Settings

    /// Encoder settings for the resample path.
    ///
    /// Only reached when geometry or frame rate changes; a codec-matching, same
    /// size render is copied rather than re-encoded. AVFoundation has no AV1
    /// encoder, so a resampled AV1 render comes out as H.264 — which is why the
    /// UI steers AV1 users away from the resampling tiers.
    func videoSettings(size: PixelSize) -> [String: Any] {
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: format.estimatedBitrate() ?? 12_000_000,
            AVVideoExpectedSourceFrameRateKey: format.frameRate.rawValue,
            AVVideoMaxKeyFrameIntervalDurationKey: 2.0,
            AVVideoAllowFrameReorderingKey: true,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ]
        if format.codec == .av1 { compression.removeValue(forKey: AVVideoProfileLevelKey) }

        return [
            AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: compression,
        ]
    }

    func audioSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 256_000,
        ]
    }

    // MARK: - Extras

    /// Writes the model's audio out on its own, for use in an editor.
    func extractWAV(from asset: AVAsset, next destination: URL) async throws -> URL? {
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

        let queue = DispatchQueue(label: "halation.encode.wav")
        // Routed through the Sendable channel for the same reason as the main
        // pumps: AVFoundation's types are not Sendable, and the safety argument
        // is that the block runs serially on the queue we hand it.
        let channel = AudioPumpChannel(readerOutput: output, writerInput: input)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            channel.writerInput.requestMediaDataWhenReady(on: queue) {
                while channel.writerInput.isReadyForMoreMediaData {
                    guard let sample = channel.readerOutput.copyNextSampleBuffer() else {
                        channel.writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                    if !channel.writerInput.append(sample) {
                        channel.writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }

    func makeThumbnail(asset: AVAsset, next destination: URL) async throws -> URL? {
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

    func replaceItem(at destination: URL, with source: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: source, to: destination)
    }
}
