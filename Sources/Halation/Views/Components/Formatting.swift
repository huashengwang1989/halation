import Foundation
import SwiftUI

enum Format {
    /// Disk and downloads, in the decimal units Apple labels storage with:
    /// 137_438_953_472 bytes reads "137.44 GB", the same as in Finder.
    static func bytes(_ value: Int64?) -> String {
        guard let value, value > 0 else { return "—" }
        return value.formatted(.byteCount(style: .file).locale(Localization.currentLocale))
    }

    /// Memory, in the binary units Apple labels *RAM* with. The distinction is
    /// not pedantry: a 128 GB Mac holds 137_438_953_472 bytes, so formatting it
    /// as storage prints "137.44 GB installed" under a column headed "128 GB",
    /// and the table contradicts itself. `.memory` divides by 1024 and prints
    /// "128 GB", which is what About This Mac says.
    static func memory(_ value: Int64?) -> String {
        guard let value, value > 0 else { return "—" }
        return value.formatted(.byteCount(style: .memory).locale(Localization.currentLocale))
    }

    /// The duration badge on a clip: "5 s", "5 秒".
    static func clipLength(_ seconds: Int) -> String {
        loc("format.clipLength", "\(seconds)")
    }

    static func frames(_ count: Int) -> String { loc("format.frames", "\(count)") }

    static func steps(_ count: Int) -> String { loc("format.steps", "\(count)") }

    /// "124 frames · 5.17 s" — what the model will actually produce.
    static func framesAndLength(_ frames: Int, seconds: Double) -> String {
        let text = seconds.formatted(
            .number.precision(.fractionLength(2)).locale(Localization.currentLocale))
        return loc("format.framesAndLength", "\(frames)", text)
    }

    /// Compact, human durations: "48 min", "2 h 10 min".
    static func duration(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
        if seconds < 60 { return loc("format.seconds", "\(Int(seconds))") }
        if seconds < 3600 { return loc("format.minutes", "\(Int((seconds / 60).rounded()))") }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return minutes == 0
            ? loc("format.hours", "\(hours)")
            : loc("format.hoursMinutes", "\(hours)", "\(minutes)")
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
        // Without this the phrasing follows the process, not the language the
        // user picked, and stays in the old one until the app is relaunched.
        formatter.locale = Localization.currentLocale
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
