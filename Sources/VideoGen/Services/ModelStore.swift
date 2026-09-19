import Foundation
import Observation

/// A model found on disk in the shared models folder.
struct InstalledModel: Identifiable, Sendable, Hashable {
    enum Layout: Sendable, Hashable {
        /// `huggingface/hub/models--org--name/snapshots/<sha>/…`, the layout
        /// `huggingface_hub` itself uses. Shared with any other tool pointed at
        /// the same `HF_HOME`, so downloads are deduplicated for free.
        case huggingFaceCache(revision: String)
        /// A plain `org/name/` or `name/` directory someone unpacked by hand.
        case flatDirectory

        var label: String {
            switch self {
            case .huggingFaceCache: "Hugging Face cache"
            case .flatDirectory: "Folder"
            }
        }
    }

    var id: String { "\(repoID)|\(url.path)" }
    var repoID: String
    var url: URL
    var layout: Layout
    var sizeBytes: Int64
    var modifiedAt: Date
    /// Which catalog entries this download satisfies. Empty means "recognised as a
    /// model, but not one we know how to drive".
    var matchedEntryIDs: Set<String> = []

    var isKnown: Bool { !matchedEntryIDs.isEmpty }
}

/// Owns the shared models folder: creates it, scans it, and reports free space.
@MainActor
@Observable
final class ModelStore {
    /// The folder is deliberately shared with other projects, so we never delete
    /// anything we did not create and never assume exclusive ownership.
    nonisolated static let defaultRootURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: "Documents/AI Models", directoryHint: .isDirectory)

    private(set) var rootURL: URL
    private(set) var installed: [InstalledModel] = []
    private(set) var isScanning = false
    private(set) var lastScanError: String?
    private(set) var freeBytes: Int64 = 0

    /// `HF_HOME` for every sidecar we spawn. Setting this is what makes a model
    /// downloaded by this app visible to other projects, and vice versa.
    var huggingFaceHome: URL {
        rootURL.appending(path: "huggingface", directoryHint: .isDirectory)
    }

    private var hubURL: URL {
        huggingFaceHome.appending(path: "hub", directoryHint: .isDirectory)
    }

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else if let stored = UserDefaults.standard.url(forKey: Self.rootDefaultsKey) {
            self.rootURL = stored
        } else {
            self.rootURL = Self.defaultRootURL
        }
    }

    nonisolated static let rootDefaultsKey = "modelsRootURL"

    func setRoot(_ url: URL) {
        rootURL = url
        UserDefaults.standard.set(url, forKey: Self.rootDefaultsKey)
        Task { await scan() }
    }

    /// Creates the folder tree if it isn't there. Safe to call repeatedly.
    func ensureRootExists() throws {
        let fm = FileManager.default
        for url in [rootURL, huggingFaceHome, hubURL]
        where !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        // A short note for anyone who opens the folder wondering what it is.
        let readme = rootURL.appending(path: "README.txt")
        if !fm.fileExists(atPath: readme.path) {
            let text = """
                Shared AI model folder
                ======================

                Machine-learning weights live here so that several projects can share
                one copy instead of each downloading its own.

                  huggingface/   Hugging Face cache (HF_HOME). Anything that respects
                                 HF_HOME and points at this folder will reuse these
                                 downloads automatically.

                You can also drop unpacked model folders directly in here, named
                <org>/<model> — they will be picked up on the next scan.

                Deleting a model frees disk space but another project may be relying
                on it.
                """
            try? text.write(to: readme, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Scanning

    func scan() async {
        isScanning = true
        lastScanError = nil
        defer { isScanning = false }

        do {
            try ensureRootExists()
        } catch {
            lastScanError = "Could not create \(rootURL.path): \(error.localizedDescription)"
            return
        }

        let root = rootURL
        let hub = hubURL
        // Sizing a 60 GB tree touches tens of thousands of files, so it happens off
        // the main actor.
        let found = await Task.detached(priority: .utility) {
            ModelScanner.scan(root: root, hub: hub)
        }.value

        installed = found.sorted { $0.repoID.localizedStandardCompare($1.repoID) == .orderedAscending }
        freeBytes = Self.availableCapacity(at: root)
    }

    var installedEntryIDs: Set<String> {
        installed.reduce(into: Set<String>()) { $0.formUnion($1.matchedEntryIDs) }
    }

    func isInstalled(_ entry: CatalogEntry) -> Bool {
        installedEntryIDs.contains(entry.id)
    }

    func installedModel(for entry: CatalogEntry) -> InstalledModel? {
        installed.first { $0.matchedEntryIDs.contains(entry.id) }
    }

    /// Local path to hand to the sidecar: the component's own folder when the
    /// repository holds several, otherwise the snapshot root.
    func localPath(for entry: CatalogEntry) -> URL? {
        guard let root = installedModel(for: entry)?.url else { return nil }
        guard let subpath = entry.componentSubpath else { return root }
        let component = root.appending(path: subpath, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: component.path) ? component : root
    }

    var totalInstalledBytes: Int64 {
        installed.reduce(0) { $0 + $1.sizeBytes }
    }

    nonisolated static func availableCapacity(at url: URL) -> Int64 {
        let probe = FileManager.default.fileExists(atPath: url.path)
            ? url
            : FileManager.default.homeDirectoryForCurrentUser
        let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    /// Whether a set of entries will fit, with a safety margin for scratch space.
    func canAccommodate(_ entries: [CatalogEntry], marginBytes: Int64 = 20 * 1_073_741_824) -> Bool {
        let needed = entries.filter { !isInstalled($0) }.reduce(Int64(0)) { $0 + $1.approximateBytes }
        return needed + marginBytes <= freeBytes
    }

    func requiredBytes(for entries: [CatalogEntry]) -> Int64 {
        entries.filter { !isInstalled($0) }.reduce(0) { $0 + $1.approximateBytes }
    }
}

/// Pure, off-actor filesystem walk.
enum ModelScanner {
    static func scan(root: URL, hub: URL) -> [InstalledModel] {
        var results: [InstalledModel] = []
        results.append(contentsOf: scanHuggingFaceCache(hub: hub))
        results.append(contentsOf: scanFlatDirectories(root: root, excluding: hub))
        return results
    }

    // MARK: Hugging Face cache

    private static func scanHuggingFaceCache(hub: URL) -> [InstalledModel] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: hub, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return [] }

        var results: [InstalledModel] = []
        for child in children {
            let name = child.lastPathComponent
            guard name.hasPrefix("models--") else { continue }
            // models--MiniMaxAI--MiniMax-H3  ->  MiniMaxAI/MiniMax-H3
            let repoID = name
                .replacingOccurrences(of: "models--", with: "")
                .replacingOccurrences(of: "--", with: "/")

            let snapshots = child.appending(path: "snapshots", directoryHint: .isDirectory)
            guard let revisions = try? fm.contentsOfDirectory(
                at: snapshots, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])
            else { continue }

            // Prefer the most recently written revision.
            let newest = revisions.max { lhs, rhs in
                modifiedDate(of: lhs) < modifiedDate(of: rhs)
            }
            guard let revision = newest, containsModelFiles(revision) else { continue }

            // Blobs hold the real bytes; snapshots are symlinks into them.
            let blobs = child.appending(path: "blobs", directoryHint: .isDirectory)
            let size = directorySize(fm.fileExists(atPath: blobs.path) ? blobs : revision)
            let modified = (try? revision.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast

            results.append(InstalledModel(
                repoID: repoID,
                url: revision,
                layout: .huggingFaceCache(revision: revision.lastPathComponent),
                sizeBytes: size,
                modifiedAt: modified,
                matchedEntryIDs: matchEntries(repoID: repoID, directory: revision)))
        }
        return results
    }

    // MARK: Hand-placed folders

    private static func scanFlatDirectories(root: URL, excluding hub: URL) -> [InstalledModel] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return [] }

        var results: [InstalledModel] = []
        for child in children {
            guard (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            // Never re-report the HF cache as a loose folder.
            if child.lastPathComponent == "huggingface" { continue }

            if containsModelFiles(child) {
                results.append(make(repoID: child.lastPathComponent, at: child))
                continue
            }
            // One level deeper: <org>/<model>.
            if let grandchildren = try? fm.contentsOfDirectory(
                at: child, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for grandchild in grandchildren where containsModelFiles(grandchild) {
                    results.append(make(
                        repoID: "\(child.lastPathComponent)/\(grandchild.lastPathComponent)",
                        at: grandchild))
                }
            }
        }
        return results
    }

    private static func make(repoID: String, at url: URL) -> InstalledModel {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast
        return InstalledModel(
            repoID: repoID,
            url: url,
            layout: .flatDirectory,
            sizeBytes: directorySize(url),
            modifiedAt: modified,
            matchedEntryIDs: matchEntries(repoID: repoID, directory: url))
    }

    // MARK: Helpers

    /// A directory counts as a model if it holds weights or a recognisable config.
    private static func containsModelFiles(_ url: URL) -> Bool {
        let fm = FileManager.default
        let markers = ["config.json", "model_index.json", "model.safetensors.index.json"]
        for marker in markers where fm.fileExists(atPath: url.appending(path: marker).path) {
            return true
        }
        guard let entries = try? fm.contentsOfDirectory(atPath: url.path) else { return false }
        return entries.contains { $0.hasSuffix(".safetensors") || $0.hasSuffix(".gguf") }
    }

    /// Maps a download onto the catalog entries it satisfies.
    ///
    /// One repository can satisfy several entries — the upstream release carries the
    /// text encoder, the VAEs and the Ref2VA transformer side by side — so each
    /// entry is confirmed by its own marker path rather than by the repo id alone.
    private static func matchEntries(repoID: String, directory: URL) -> Set<String> {
        let fm = FileManager.default
        var matched = Set<String>()
        for entry in ModelCatalog.all
        where entry.repoID.caseInsensitiveCompare(repoID) == .orderedSame {
            let marker = directory.appending(path: entry.markerPath)
            guard fm.fileExists(atPath: marker.path)
                    || (entry.componentSubpath == nil && containsModelFiles(directory))
            else { continue }

            // An interrupted transfer can leave the config files behind without the
            // weights, so a marker alone is not proof — require real tensors in the
            // folder this entry resolves to.
            let weightsRoot = entry.componentSubpath
                .map { directory.appending(path: $0, directoryHint: .isDirectory) } ?? directory
            if containsWeights(weightsRoot) { matched.insert(entry.id) }
        }
        return matched
    }

    /// True when the tree holds at least one real weight file. Cheap: it stops at
    /// the first hit rather than walking a 60 GB directory to completion.
    private static func containsWeights(_ url: URL) -> Bool {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else { return false }
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "safetensors" || ext == "gguf" || ext == "bin" { return true }
        }
        return false
    }

    private static func modifiedDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles])
        else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]),
                values.isRegularFile == true
            else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
