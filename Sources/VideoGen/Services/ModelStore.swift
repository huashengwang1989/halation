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
        // Always bumped, even when `installed` comes back identical: a ComfyUI
        // weight that just landed never appears there, and without this the row
        // that asked about it would keep its old answer.
        defer { isScanning = false; revision += 1 }

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

    /// Bumped whenever the folder may have changed on disk.
    ///
    /// ComfyUI weights are plain files, tested with `fileExists` rather than held
    /// in `installed`, and a file appearing on disk is not something `@Observable`
    /// can notice. Anything that answers "is this installed" reads this too, so a
    /// scan after a download actually redraws the rows that asked.
    private(set) var revision = 0

    /// Every catalog entry present on disk, in either layout.
    ///
    /// ComfyUI weights are plain files in the shared folder rather than Hugging
    /// Face cache entries, so they never appear in `installed` and used to look
    /// missing to everything that reasons about what is available — selection,
    /// validation, the recommended bundle. The handful of `stat` calls this costs
    /// is nothing beside a SwiftUI layout pass.
    var installedEntryIDs: Set<String> {
        _ = revision  // observation dependency; see `revision`.
        var ids = installed.reduce(into: Set<String>()) { $0.formUnion($1.matchedEntryIDs) }
        for entry in ModelCatalog.all {
            guard let file = entry.comfyUIFile else { continue }
            if FileManager.default.fileExists(atPath: comfyUIPath(for: file).path) {
                ids.insert(entry.id)
            }
        }
        return ids
    }

    func isInstalled(_ entry: CatalogEntry) -> Bool {
        _ = revision  // observation dependency; see `revision`.
        if let file = entry.comfyUIFile {
            return FileManager.default.fileExists(atPath: comfyUIPath(for: file).path)
        }
        return installed.contains { $0.matchedEntryIDs.contains(entry.id) }
    }

    /// Where a ComfyUI-format weight lives inside the shared folder.
    func comfyUIPath(for file: CatalogEntry.ComfyUIFile) -> URL {
        rootURL
            .appending(path: "comfyui", directoryHint: .isDirectory)
            .appending(path: file.folder, directoryHint: .isDirectory)
            .appending(path: file.filename)
    }

    func installedModel(for entry: CatalogEntry) -> InstalledModel? {
        installed.first { $0.matchedEntryIDs.contains(entry.id) }
    }

    /// Local path to hand to the sidecar: the component's own folder when the
    /// repository holds several, otherwise the snapshot root.
    func localPath(for entry: CatalogEntry) -> URL? {
        if let file = entry.comfyUIFile {
            let path = comfyUIPath(for: file)
            return FileManager.default.fileExists(atPath: path.path) ? path : nil
        }
        guard let root = installedModel(for: entry)?.url else { return nil }
        guard let subpath = entry.componentSubpath else { return root }
        let component = root.appending(path: subpath, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: component.path) ? component : root
    }

    var totalInstalledBytes: Int64 {
        installed.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Moves a model's files to the Trash and returns the bytes reclaimed.
    ///
    /// Two shapes to handle. A ComfyUI weight is one plain file. A Hugging Face
    /// entry is a directory of symlinks into a content-addressed store, so the
    /// links alone are worth nothing — the targets have to go too, or we would
    /// claim to free 67 GB while freeing a few kilobytes.
    ///
    /// Targets outside the models root are never touched.
    @discardableResult
    func delete(_ entry: CatalogEntry) throws -> Int64 {
        let fm = FileManager.default

        if let file = entry.comfyUIFile {
            let path = comfyUIPath(for: file)
            let size = (try? path.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            try fm.trashItem(at: path, resultingItemURL: nil)
            Task { await scan() }
            return size
        }

        guard let component = localPath(for: entry) else { return 0 }
        let root = rootURL.standardizedFileURL.path

        // Collect what the links actually point at before removing them.
        var targets: Set<URL> = []
        var freed: Int64 = 0
        if let walker = fm.enumerator(at: component,
                                      includingPropertiesForKeys: [.isSymbolicLinkKey],
                                      options: [.skipsHiddenFiles]) {
            for case let file as URL in walker {
                let values = try? file.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values?.isSymbolicLink == true else { continue }
                let target = file.resolvingSymlinksInPath().standardizedFileURL
                guard target.path.hasPrefix(root) else { continue }   // never leave the folder
                targets.insert(target)
            }
        }

        for target in targets {
            let size = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            if (try? fm.trashItem(at: target, resultingItemURL: nil)) != nil { freed += size }
        }
        try fm.trashItem(at: component, resultingItemURL: nil)

        Task { await scan() }
        return freed
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
