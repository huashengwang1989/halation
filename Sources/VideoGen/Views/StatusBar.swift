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

            Spacer(minLength: 8)

            if let bytes = app.engine.activeMemoryBytes {
                memory(bytes)
            }

            if app.engine.queuedCount > 0 {
                Divider().frame(height: 12)
                Label("\(app.engine.queuedCount) queued", systemImage: "list.bullet")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status")
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
        Text(job.title)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
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
            parts.append("step \(job.completedSteps)/\(job.totalSteps)")
        }
        if let remaining = job.estimatedRemaining {
            parts.append("\(Format.duration(remaining)) left")
        } else if let elapsed = job.elapsed {
            parts.append(Format.duration(elapsed))
        }
        return parts.joined(separator: " · ")
    }

    /// Megabytes below a gigabyte, gigabytes above — and the share of installed
    /// memory, which is the number that tells you whether you are about to swap.
    private func memory(_ bytes: Int64) -> some View {
        let share = Double(bytes) / Double(ProcessMemory.physicalBytes)
        return HStack(spacing: 4) {
            Image(systemName: "memorychip")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(Self.memoryText(bytes))
            Text("(\(Int(share * 100))%)")
                .foregroundStyle(share > 0.85 ? .orange : .secondary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .help("Resident memory of the render process, and its share of this Mac's "
              + "\(Format.bytes(ProcessMemory.physicalBytes))")
    }

    static func memoryText(_ bytes: Int64) -> String {
        let megabytes = Double(bytes) / 1_048_576
        if megabytes < 1024 {
            return "\(Int(megabytes.rounded())) MB"
        }
        return String(format: "%.1f GB", megabytes / 1024)
    }

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
        case .ready(let report): return report.h3Usable ? "Ready" : "Runtime incomplete"
        case .installing(let step, _): return step
        case .failed: return "Runtime error"
        case .missing: return "Runtime not installed"
        case .unknown: return "Checking…"
        }
    }

    private var spokenStatus: String {
        var parts = [statusText]
        if let job = app.engine.activeJob {
            parts.append(job.title)
            parts.append("\(Int(job.overallProgress * 100)) percent")
            if let remaining = job.estimatedRemaining {
                parts.append("about \(Format.duration(remaining)) remaining")
            }
        }
        if let bytes = app.engine.activeMemoryBytes {
            parts.append("using \(Self.memoryText(bytes))")
        }
        return parts.joined(separator: ", ")
    }
}
