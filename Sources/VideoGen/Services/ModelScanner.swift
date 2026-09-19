import Foundation

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
            // No `containsModelFiles` gate here: a `models--` directory in the hub
            // is a model by construction, and requiring marker files at the
            // snapshot root wrongly rejected the upstream release, whose root
            // holds only the `FL2VA/` and `Ref2VA/` task folders. Which catalog
            // entries a download actually satisfies is `matchEntries`' job.
            guard let revision = newest else { continue }

            // Size the snapshot and follow its links. Sizing `blobs/` directly
            // used to work, but under Xet storage those are links too.
            let size = directorySize(revision)
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

    /// A directory counts as a model if it holds weights or a recognisable config,
    /// at its root or one level down.
    ///
    /// The extra level matters: a released checkpoint may put everything inside a
    /// task folder, so a root-only test reports a complete 78 GB download as not
    /// a model at all.
    private static func containsModelFiles(_ url: URL, depth: Int = 1) -> Bool {
        let fm = FileManager.default
        let markers = ["config.json", "model_index.json", "model.safetensors.index.json"]
        for marker in markers where fm.fileExists(atPath: url.appending(path: marker).path) {
            return true
        }
        guard let entries = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return false }

        if entries.contains(where: {
            let ext = $0.pathExtension.lowercased()
            return ext == "safetensors" || ext == "gguf"
        }) { return true }

        guard depth > 0 else { return false }
        return entries.contains {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            && containsModelFiles($0, depth: depth - 1)
        }
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

    /// Size of a model on disk, following symlinks.
    ///
    /// `huggingface_hub` 1.x stores content in a shared, chunk-deduplicated Xet
    /// tree and leaves the per-repo blobs as symlinks into it. Counting only
    /// regular files therefore reported a 96 GB install as a few megabytes.
    /// Resolved paths are deduplicated so a blob shared between two files in the
    /// same repo is not counted twice.
    private static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles])
        else { return 0 }

        var total: Int64 = 0
        var counted = Set<String>()

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey])

            // A symlink is followed to whatever it finally points at, which may
            // itself be another link inside the Xet store.
            let target = values?.isSymbolicLink == true
                ? fileURL.resolvingSymlinksInPath()
                : fileURL
            guard values?.isRegularFile == true || values?.isSymbolicLink == true else { continue }

            let key = target.standardizedFileURL.path
            guard counted.insert(key).inserted else { continue }

            guard let size = try? target.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { continue }
            total += Int64(size.totalFileAllocatedSize ?? size.fileAllocatedSize ?? 0)
        }
        return total
    }
}
