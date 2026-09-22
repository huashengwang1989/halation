import SwiftUI

/// A thin strip across the bottom of the window, in the spirit of Finder's path
/// bar: always present, never in the way.
///
/// Replaces the progress readout that used to sit under the sidebar, which was
/// cramped and disappeared whenever the sidebar was collapsed — exactly when a
/// long render most needed watching.
struct StatusBar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 10) {
            healthDot
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            if let job = app.engine.activeJob {
                Divider().frame(height: 12)
                activity(for: job)
            }

            if let note = app.note {
                Divider().frame(height: 12)
                Label(note, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            Spacer(minLength: 8)

            if let usage = app.engine.memoryUsage {
                memory(usage)
            }

            if app.engine.queuedCount > 0 {
                Divider().frame(height: 12)
                Label(loc("status.queued.count", "\(app.engine.queuedCount)"),
                      systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        // The bar covers this much of the window. Published rather than assumed:
        // it grows by a line while a render runs, and by more in languages with
        // taller metrics. See `statusBarInset()`.
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: StatusBarHeightKey.self,
                                       value: proxy.size.height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loc("status.label"))
        .accessibilityValue(spokenStatus)
    }

    // MARK: - Pieces

    private var healthDot: some View {
        Circle()
            .fill(healthColor)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func activity(for job: RenderJob) -> some View {
        // Two lines at most, and tail truncation so the ellipsis lands where a
        // reader stops rather than in the middle of the phrase.
        Text(job.title)
            .font(.caption)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: 220, alignment: .leading)

        // Indeterminate while loading: a bar at 1% reads as stuck, and weights
        // take minutes before the first step lands.
        if job.state == .preparing, (job.stageProgress ?? 0) <= 0 {
            ProgressView()
                .progressViewStyle(.linear)
                .frame(width: 110)
        } else {
            ProgressView(value: job.overallProgress)
                .progressViewStyle(.linear)
                .frame(width: 110)
        }

        Text(detail(for: job))
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    private func detail(for job: RenderJob) -> String {
        var parts: [String] = []
        if job.totalSteps > 0 {
            parts.append(loc("status.step", "\(job.completedSteps)", "\(job.totalSteps)"))
        }
        if let remaining = job.estimatedRemaining {
            parts.append(loc("status.remaining", Format.duration(remaining)))
        } else if let elapsed = job.elapsed {
            parts.append(Format.duration(elapsed))
        }
        return parts.joined(separator: " · ")
    }

    /// Megabytes below a gigabyte, gigabytes above — and the share of installed
    /// memory, which is the number that tells you whether you are about to swap.
    ///
    /// The total of the app and the engine, with the peak beside it. The peak is
    /// the one worth keeping: a render that touched ninety per cent for a few
    /// seconds and settled back leaves no other trace that it nearly swapped.
    private func memory(_ usage: RenderEngine.MemoryUsage) -> some View {
        let share = Double(usage.totalBytes) / Double(ProcessMemory.physicalBytes)
        return HStack(spacing: 4) {
            Image(systemName: "memorychip")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(Self.memoryText(usage.totalBytes))
            Text("(\(Int(share * 100))%)")
                .foregroundStyle(share > 0.85 ? .orange : .secondary)
            if usage.peakTotalBytes > usage.totalBytes {
                Text("· " + loc("status.memory.peak",
                                Self.memoryText(usage.peakTotalBytes)))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .help(loc("status.memory.breakdown",
                  Self.memoryText(usage.engineBytes),
                  Self.memoryText(usage.appBytes),
                  Self.memoryText(usage.peakTotalBytes),
                  Format.memory(ProcessMemory.physicalBytes)))
    }

    static func memoryText(_ bytes: Int64) -> String { Format.memory(bytes) }

    // MARK: - State

    private var healthColor: Color {
        if app.engine.activeJob != nil { return .accentColor }
        switch app.runtime.phase {
        case .ready(let report): return report.h3Usable ? .green : .orange
        case .installing: return .blue
        case .failed: return .red
        case .missing, .unknown: return .orange
        }
    }

    private var statusText: String {
        if let job = app.engine.activeJob {
            return job.activityDescription
        }
        switch app.runtime.phase {
        case .ready(let report):
            return report.h3Usable ? loc("status.ready") : loc("status.runtime.incomplete")
        case .installing(let step, _): return step
        case .failed: return loc("status.runtime.error")
        case .missing: return loc("status.runtime.missing")
        case .unknown: return loc("status.checking")
        }
    }

    private var spokenStatus: String {
        var parts = [statusText]
        if let job = app.engine.activeJob {
            parts.append(job.title)
            parts.append(loc("a11y.percent", "\(Int(job.overallProgress * 100))"))
            if let remaining = job.estimatedRemaining {
                parts.append(loc("a11y.remaining", Format.duration(remaining)))
            }
        }
        if let usage = app.engine.memoryUsage {
            parts.append(loc("a11y.usingMemory", Self.memoryText(usage.totalBytes)))
        }
        return parts.joined(separator: ", ")
    }
}
