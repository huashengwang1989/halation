import Foundation
import Observation

/// What the app has left on disk that can be deleted without losing anything.
///
/// Deliberately excludes the two things that look like the biggest wins and are
/// not caches at all: the model weights, which cost 105 GB and hours to fetch
/// again, and the finished videos. Both live in folders the user chose, are
/// managed from the Folders tab, and are never touched from here.
///
/// The Python runtime and the ComfyUI checkout are also absent. They are large —
/// 2.3 GB between them — but they are an installation rather than a cache, and
/// Settings ▸ Runtime already offers to rebuild them with the warning that
/// belongs to that.
@MainActor
@Observable
final class CacheInventory {

    struct Category: Identifiable, Sendable {
        let id: String
        /// Localization keys rather than text: this is built once and the user
        /// can change language while the window is open.
        let titleKey: String
        let detailKey: String
        let locations: [URL]
        var bytes: Int64 = 0
    }

    private(set) var categories: [Category] = []
    private(set) var isMeasuring = false
    /// False until the first walk finishes.
    ///
    /// Needed because "no bytes yet" and "no bytes at all" look identical from
    /// the outside, and the tab was reporting the first as the second: it said
    /// "Nothing cached" for a second on arrival, then filled in gigabytes.
    /// Only the first measurement is hidden behind this — later ones keep the
    /// previous figures on screen rather than blanking them.
    private(set) var hasMeasured = false

    private let support: URL
    private let comfyUI: URL

    init(support: URL = RuntimeManager.supportDirectory) {
        self.support = support
        self.comfyUI = support.appending(path: "comfyui")
        categories = [
            // uv's default cache, not one the app sets. Named as shared so the
            // user knows what they are emptying — see the detail string.
            .init(id: "uv", titleKey: "settings.cache.uv",
                  detailKey: "settings.cache.uv.detail",
                  locations: [FileManager.default.homeDirectoryForCurrentUser
                      .appending(path: ".cache/uv")]),
            .init(id: "bytecode", titleKey: "settings.cache.bytecode",
                  detailKey: "settings.cache.bytecode.detail",
                  locations: []),          // found by search; see measure()
            .init(id: "comfyOutput", titleKey: "settings.cache.comfyOutput",
                  detailKey: "settings.cache.comfyOutput.detail",
                  locations: [comfyUI.appending(path: "output"),
                              comfyUI.appending(path: "input"),
                              comfyUI.appending(path: "temp")]),
            .init(id: "scratch", titleKey: "settings.cache.scratch",
                  detailKey: "settings.cache.scratch.detail",
                  locations: [support.appending(path: "scratch")]),
        ]
    }

    var totalBytes: Int64 { categories.reduce(0) { $0 + $1.bytes } }

    func refresh() async {
        isMeasuring = true
        defer {
            isMeasuring = false
            hasMeasured = true
        }

        let support = self.support
        let resolved = categories.map { category -> (String, [URL]) in
            (category.id, category.id == "bytecode"
                ? Self.bytecodeDirectories(under: support)
                : category.locations)
        }

        // Off the main actor: walking a 3 GB cache directory takes long enough
        // to drop frames if it runs where the UI does.
        let sizes = await Task.detached(priority: .utility) {
            resolved.reduce(into: [String: Int64]()) { result, entry in
                result[entry.0] = entry.1.reduce(0) { $0 + Self.size(of: $1) }
            }
        }.value

        for index in categories.indices {
            categories[index].bytes = sizes[categories[index].id] ?? 0
            if categories[index].id == "bytecode" {
                categories[index] = Category(
                    id: "bytecode", titleKey: categories[index].titleKey,
                    detailKey: categories[index].detailKey,
                    locations: Self.bytecodeDirectories(under: support),
                    bytes: categories[index].bytes)
            }
        }
    }

    /// Removes a category's contents, leaving the directories themselves.
    ///
    /// The directory is kept because something else may hold a handle on it —
    /// ComfyUI expects its own output folder to exist — and recreating a
    /// directory is cheaper than discovering which component assumed it.
    func clear(_ category: Category) async {
        let locations = category.id == "bytecode"
            ? Self.bytecodeDirectories(under: support)
            : category.locations
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            for url in locations {
                guard let contents = try? fm.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil) else { continue }
                for item in contents { try? fm.removeItem(at: item) }
            }
        }.value
        await refresh()
    }

    func clearAll() async {
        for category in categories { await clear(category) }
    }

    // MARK: - Measuring

    /// Allocated size rather than logical, so the figure matches the Finder's.
    private nonisolated static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: [], errorHandler: { _, _ in true })
        else { return 0 }

        var total: Int64 = 0
        for case let item as URL in enumerator {
            let values = try? item.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    private nonisolated static func bytecodeDirectories(under root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey],
            options: [], errorHandler: { _, _ in true })
        else { return [] }

        var found: [URL] = []
        for case let item as URL in enumerator where item.lastPathComponent == "__pycache__" {
            found.append(item)
            // Nothing inside a __pycache__ is another one.
            enumerator.skipDescendants()
        }
        return found
    }
}
