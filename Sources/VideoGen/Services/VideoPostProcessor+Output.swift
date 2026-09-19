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

    func videoSettings(size: PixelSize) -> [String: Any] {
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

    func audioSettings() -> [String: Any] {
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
