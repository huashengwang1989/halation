import Foundation
import Observation

/// Downloads catalog entries into the shared Hugging Face cache.
///
/// Transfers run one repo at a time: these are tens of gigabytes each, and parallel
/// downloads on one link just make every progress bar slower without finishing sooner.
@MainActor
@Observable
final class DownloadManager {
    struct Transfer: Identifiable, Sendable {
        var id: String { entry.id }
        var entry: CatalogEntry
        var completedBytes: Int64 = 0
        var totalBytes: Int64 = 0
        var currentFile: String?
        var state: State = .waiting
        var message: String?
        /// Bytes are all in, but the hub is still verifying and linking. Without
        /// this the UI shows a full bar for minutes with no explanation.
        var isFinalising = false

        enum State: Sendable, Equatable {
            case waiting, active, finished, failed, cancelled

            var isTerminal: Bool {
                switch self {
                case .finished, .failed, .cancelled: true
                default: false
                }
            }
        }

        var fraction: Double {
            guard totalBytes > 0 else { return state == .finished ? 1 : 0 }
            return min(1, Double(completedBytes) / Double(totalBytes))
        }
    }

    private(set) var transfers: [Transfer] = []
    private(set) var isDownloading = false

    private let runtime: RuntimeManager
    private let modelStore: ModelStore
    private var runner: ProcessRunner?
    private var pumpTask: Task<Void, Never>?
    private var cancelledIDs = Set<String>()

    init(runtime: RuntimeManager, modelStore: ModelStore) {
        self.runtime = runtime
        self.modelStore = modelStore
    }

    var activeTransfer: Transfer? { transfers.first { $0.state == .active } }
    var pendingCount: Int { transfers.count { !$0.state.isTerminal } }

    /// Total bytes still to fetch across the whole queue, for the pre-flight check.
    var remainingBytes: Int64 {
        transfers.filter { !$0.state.isTerminal }
            .reduce(0) { $0 + max($1.entry.approximateBytes - $1.completedBytes, 0) }
    }

    /// Queues anything in `entries` that is not already installed or already
    /// queued.
    ///
    /// Deduplication is by catalog entry and ignores state: a finished row is
    /// still that entry's row. Re-running "Install Recommended" used to append a
    /// second copy of every completed item, which then raced the first for the
    /// same cache directory and reported nonsense.
    func enqueue(_ entries: [CatalogEntry]) {
        for entry in entries {
            guard entry.isUsableHere, !modelStore.isInstalled(entry) else { continue }

            if let existing = transfers.firstIndex(where: { $0.entry.id == entry.id }) {
                // Present already. Retry it in place if it stopped short;
                // otherwise leave it alone.
                if transfers[existing].state == .failed || transfers[existing].state == .cancelled {
                    transfers[existing] = Transfer(entry: entry, totalBytes: entry.approximateBytes)
                }
                continue
            }
            transfers.append(Transfer(entry: entry, totalBytes: entry.approximateBytes))
        }
        startNextIfIdle()
    }

    /// True once at least one transfer has run this session, so the Downloads
    /// card can stay on screen with its history instead of vanishing the moment
    /// the last one finishes.
    var hasHistory: Bool { !transfers.isEmpty }

    func cancel(_ id: String) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else { return }
        if transfers[index].state == .active {
            cancelledIDs.insert(id)
            pumpTask?.cancel()
            Task { await runner?.terminate() }
        } else {
            transfers[index].state = .cancelled
        }
    }

    func cancelAll() {
        for transfer in transfers where !transfer.state.isTerminal { cancel(transfer.id) }
    }

    func clearFinished() {
        transfers.removeAll { $0.state.isTerminal }
    }

    private func startNextIfIdle() {
        guard !isDownloading, runtime.isInstalled,
              let next = transfers.first(where: { $0.state == .waiting })
        else { return }
        pumpTask = Task { await run(id: next.id) }
    }

    private func run(id: String) async {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else { return }
        isDownloading = true
        defer {
            isDownloading = false
            Task {
                await modelStore.scan()
                startNextIfIdle()
            }
        }

        transfers[index].state = .active
        let entry = transfers[index].entry

        var arguments = [runtime.sidecarScript.path, "download", "--repo", entry.repoID]
        if let patterns = entry.allowPatterns,
           let data = try? JSONSerialization.data(withJSONObject: patterns),
           let json = String(data: data, encoding: .utf8) {
            arguments += ["--patterns", json]
        }

        do {
            let runner = ProcessRunner()
            self.runner = runner
            let stream = await runner.lines(.init(
                executable: runtime.pythonURL,
                arguments: arguments,
                environment: runtime.environment()))

            for try await line in stream {
                guard let event = SidecarEvent.parse(line: line),
                      let live = transfers.firstIndex(where: { $0.id == id }) else { continue }
                switch event {
                case .downloadProgress(_, let completed, let total, let note):
                    transfers[live].completedBytes = completed
                    if total > 0 { transfers[live].totalBytes = total }
                    transfers[live].currentFile = note
                    transfers[live].isFinalising = note != nil && completed >= total && total > 0
                case .failure(let message):
                    transfers[live].message = message
                case .log(let message):
                    transfers[live].message = message
                default:
                    break
                }
            }

            guard let live = transfers.firstIndex(where: { $0.id == id }) else { return }
            if cancelledIDs.contains(id) {
                transfers[live].state = .cancelled
                cancelledIDs.remove(id)
            } else {
                transfers[live].state = .finished
                transfers[live].completedBytes = transfers[live].totalBytes
                transfers[live].currentFile = nil
                transfers[live].isFinalising = false
            }
        } catch {
            guard let live = transfers.firstIndex(where: { $0.id == id }) else { return }
            if cancelledIDs.contains(id) {
                transfers[live].state = .cancelled
                cancelledIDs.remove(id)
            } else {
                transfers[live].state = .failed
                transfers[live].message = error.localizedDescription
            }
        }
    }
}
