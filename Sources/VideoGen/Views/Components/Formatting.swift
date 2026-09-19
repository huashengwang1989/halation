import Foundation
import SwiftUI

enum Format {
    static func bytes(_ value: Int64?) -> String {
        guard let value, value > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    /// Compact, human durations: "48 min", "2 h 10 min".
    static func duration(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
        if seconds < 60 { return "\(Int(seconds)) s" }
        if seconds < 3600 { return "\(Int((seconds / 60).rounded())) min" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }

    /// A range, collapsed when the two ends round to the same thing.
    static func durationRange(_ range: ClosedRange<TimeInterval>) -> String {
        let low = duration(range.lowerBound)
        let high = duration(range.upperBound)
        return low == high ? low : "\(low) – \(high)"
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
