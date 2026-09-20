import Foundation
import Observation

/// A finished render on disk, with the recipe that produced it.
struct LibraryItem: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var videoURL: URL
    var audioURL: URL?
    var thumbnailURL: URL?
    var spec: GenerationSpec
    var createdAt: Date
    var seed: Int64?
    var renderSeconds: TimeInterval?
    var fileSizeBytes: Int64?

    var title: String {
        let trimmed = spec.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(80))
    }

    var exists: Bool { FileManager.default.fileExists(atPath: videoURL.path) }
}

/// Where finished videos go, and the index over them.
///
/// Generated videos are the user's own output, so they live in Movies rather than in
/// Application Support, and each one is written with a sidecar JSON holding the full
/// spec — so a clip is still reproducible even if this app is gone.
@MainActor
@Observable
final class LibraryStore {
    private(set) var items: [LibraryItem] = []
    private(set) var presets: [GenerationPreset] = []

    nonisolated static let outputDefaultsKey = "outputFolderURL"

    var outputFolder: URL {
        get {
            if let stored = UserDefaults.standard.url(forKey: Self.outputDefaultsKey) { return stored }
            return FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first?
                .appending(path: "Halation", directoryHint: .isDirectory)
                ?? FileManager.default.homeDirectoryForCurrentUser
                    .appending(path: "Movies/Halation", directoryHint: .isDirectory)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.outputDefaultsKey)
            reload()
        }
    }

    init() {
        presets = Self.loadPresets()
        reload()
    }

    // MARK: - Outputs

    /// A stable, readable filename derived from the prompt, de-duplicated by date.
    func destinationURL(for spec: GenerationSpec, jobID: UUID) -> URL {
        let folder = outputFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let stamp = Self.stampFormatter.string(from: .now)
        let slug = Self.slug(spec.prompt)
        let base = slug.isEmpty ? "render-\(stamp)" : "\(slug)-\(stamp)"
        var candidate = folder.appending(path: "\(base).\(spec.format.codec.fileExtension)")

        // Two renders started in the same second still get distinct names.
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: "\(base)-\(suffix).\(spec.format.codec.fileExtension)")
            suffix += 1
        }
        return candidate
    }

    func record(job: RenderJob) {
        guard let videoURL = job.outputURL else { return }
        let size = (try? videoURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init)

        let item = LibraryItem(
            id: job.id,
            videoURL: videoURL,
            audioURL: job.sidecarAudioURL,
            thumbnailURL: job.thumbnailURL,
            spec: job.spec,
            createdAt: job.finishedAt ?? .now,
            seed: job.resolvedSeed,
            renderSeconds: job.elapsed,
            fileSizeBytes: size)

        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        writeSidecar(for: item)
        persistIndex()
    }

    /// Writes the recipe next to the video. Plain JSON, readable without this app.
    private func writeSidecar(for item: LibraryItem) {
        let url = item.videoURL.deletingPathExtension().appendingPathExtension("halation.json")
        var payload: [String: Any] = [
            "app": "Halation",
            "model": "MiniMax-H3",
            "task": item.spec.task.rawValue,
            "mode": item.spec.mode.rawValue,
            "prompt": item.spec.prompt,
            "duration_seconds": item.spec.sampling.durationSeconds,
            "frames": item.spec.sampling.frameCount,
            "steps": item.spec.sampling.steps,
            "aspect_ratio": item.spec.format.aspectRatio.rawValue,
            "generation_size": item.spec.format.generationSize.description,
            "delivery_size": item.spec.format.deliverySize.description,
            "frame_rate": item.spec.format.frameRate.rawValue,
            "codec": item.spec.format.codec.rawValue,
            "created_at": ISO8601DateFormatter().string(from: item.createdAt),
        ]
        if let seed = item.seed { payload["seed"] = seed }
        if let seconds = item.renderSeconds { payload["render_seconds"] = Int(seconds) }
        if let id = item.spec.transformerEntryID { payload["transformer"] = id }

        guard let data = try? JSONSerialization.data(
            withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Rebuilds the index from the sidecar files actually present on disk, so items
    /// deleted in the Finder disappear and hand-copied ones appear.
    func reload() {
        let indexed = Self.loadIndex()
        let folder = outputFolder
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]) else {
            items = indexed.filter(\.exists)
            return
        }

        let videoExtensions: Set<String> = ["mp4", "mov"]
        var result: [LibraryItem] = []
        for url in contents where videoExtensions.contains(url.pathExtension.lowercased()) {
            if let known = indexed.first(where: { $0.videoURL.standardizedFileURL == url.standardizedFileURL }) {
                result.append(known)
                continue
            }
            result.append(Self.reconstruct(from: url))
        }
        items = result.sorted { $0.createdAt > $1.createdAt }
        persistIndex()
    }

    /// Recovers an item from its sidecar JSON when the index is missing or stale.
    private static func reconstruct(from url: URL) -> LibraryItem {
        var spec = GenerationSpec()
        var seed: Int64?
        var created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now

        let sidecar = url.deletingPathExtension().appendingPathExtension("halation.json")
        if let data = try? Data(contentsOf: sidecar),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            spec.prompt = object["prompt"] as? String ?? ""
            spec.sampling.durationSeconds = object["duration_seconds"] as? Int ?? 5
            spec.sampling.steps = object["steps"] as? Int ?? 16
            if let ratio = object["aspect_ratio"] as? String,
               let parsed = AspectRatio(rawValue: ratio) { spec.format.aspectRatio = parsed }
            if let fps = object["frame_rate"] as? Int,
               let parsed = FrameRate(rawValue: fps) { spec.format.frameRate = parsed }
            if let codec = object["codec"] as? String,
               let parsed = VideoCodec(rawValue: codec) { spec.format.codec = parsed }
            if let mode = object["mode"] as? String,
               let parsed = GenerationMode(rawValue: mode) { spec.mode = parsed }
            if let value = object["seed"] as? Int { seed = Int64(value) }
            if let iso = object["created_at"] as? String,
               let parsed = ISO8601DateFormatter().date(from: iso) { created = parsed }
        } else {
            spec.prompt = url.deletingPathExtension().lastPathComponent
        }

        let thumbnail = url.deletingPathExtension().appendingPathExtension("jpg")
        let wav = url.deletingPathExtension().appendingPathExtension("wav")
        let fm = FileManager.default

        return LibraryItem(
            id: UUID(),
            videoURL: url,
            audioURL: fm.fileExists(atPath: wav.path) ? wav : nil,
            thumbnailURL: fm.fileExists(atPath: thumbnail.path) ? thumbnail : nil,
            spec: spec,
            createdAt: created,
            seed: seed,
            renderSeconds: nil,
            fileSizeBytes: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init))
    }

    /// Moves the video and everything written beside it to the Trash.
    func delete(_ item: LibraryItem) {
        let fm = FileManager.default
        let companions = [
            item.videoURL,
            item.audioURL,
            item.thumbnailURL,
            item.videoURL.deletingPathExtension().appendingPathExtension("halation.json"),
        ].compactMap { $0 }

        for url in companions where fm.fileExists(atPath: url.path) {
            try? fm.trashItem(at: url, resultingItemURL: nil)
        }
        items.removeAll { $0.id == item.id }
        persistIndex()
    }

    // MARK: - Presets

    func savePreset(name: String, spec: GenerationSpec) {
        var spec = spec
        // A preset is a recipe, not a specific clip: drop the fixed seed and the
        // file paths, which will not exist next time.
        spec.sampling.seed = nil
        spec.references = []
        presets.append(GenerationPreset(name: name, spec: spec))
        persistPresets()
    }

    func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id && !$0.isBuiltIn }
        persistPresets()
    }

    func renamePreset(_ id: UUID, to name: String) {
        guard let index = presets.firstIndex(where: { $0.id == id }), !presets[index].isBuiltIn else { return }
        presets[index].name = name
        persistPresets()
    }

    var allPresets: [GenerationPreset] { GenerationPreset.builtIns + presets }

    // MARK: - Persistence

    nonisolated private static var indexURL: URL {
        RuntimeManager.supportDirectory.appending(path: "library.json")
    }

    nonisolated private static var presetsURL: URL {
        RuntimeManager.supportDirectory.appending(path: "presets.json")
    }

    private func persistIndex() {
        let snapshot = items
        Task.detached(priority: .background) {
            try? FileManager.default.createDirectory(
                at: RuntimeManager.supportDirectory, withIntermediateDirectories: true)
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: LibraryStore.indexURL, options: .atomic)
        }
    }

    private func persistPresets() {
        let snapshot = presets
        Task.detached(priority: .background) {
            try? FileManager.default.createDirectory(
                at: RuntimeManager.supportDirectory, withIntermediateDirectories: true)
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: LibraryStore.presetsURL, options: .atomic)
        }
    }

    nonisolated private static func loadIndex() -> [LibraryItem] {
        guard let data = try? Data(contentsOf: indexURL),
              let items = try? JSONDecoder().decode([LibraryItem].self, from: data)
        else { return [] }
        return items
    }

    nonisolated private static func loadPresets() -> [GenerationPreset] {
        guard let data = try? Data(contentsOf: presetsURL),
              let presets = try? JSONDecoder().decode([GenerationPreset].self, from: data)
        else { return [] }
        return presets.filter { !$0.isBuiltIn }
    }

    // MARK: - Helpers

    nonisolated private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    nonisolated static func slug(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = text.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : " " }
            .reduce(into: "") { $0.append($1) }
        let words = cleaned.split(separator: " ").prefix(6)
        return words.joined(separator: "-").lowercased()
    }
}
