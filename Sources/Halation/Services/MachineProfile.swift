import Darwin
import Foundation

/// What this particular Mac is, for the two things the app has to size to it:
/// how long a render will take, and whether a checkpoint fits in memory at all.
///
/// Everything here is read from the machine. The app was written on one Mac, and
/// an estimate anchored to that Mac is wrong on every other — which matters as
/// soon as anyone else runs it.
enum MachineProfile {

    // MARK: - Identity

    /// e.g. `Apple M4 Max`. Empty if the machine does not report one.
    static let chipName: String = sysctlString("machdep.cpu.brand_string") ?? ""

    static var physicalBytes: Int64 { Int64(ProcessInfo.processInfo.physicalMemory) }

    // MARK: - Memory

    /// How much of unified memory the weights can realistically occupy.
    ///
    /// Apple Silicon shares one pool between CPU and GPU, so installed memory is
    /// not a budget — macOS caps what the GPU may wire down, by default around
    /// three quarters of it, and the rest goes to the window server, this app and
    /// the system. Exceeding it does not fail cleanly: it swaps, and a render that
    /// would have taken an hour takes a day.
    static var usableWeightBytes: Int64 { physicalBytes * 3 / 4 }

    /// Whether a given resident footprint fits, and how comfortably.
    enum Fit {
        case comfortable
        /// Fits inside the budget, but with little room for anything else.
        case tight
        case tooLarge

        var isUsable: Bool { self != .tooLarge }
    }

    static func fit(residentBytes: Int64) -> Fit {
        let budget = usableWeightBytes
        if residentBytes > budget { return .tooLarge }
        if Double(residentBytes) > Double(budget) * 0.85 { return .tight }
        return .comfortable
    }

    // MARK: - Speed

    /// Rough memory bandwidth, in GB/s.
    ///
    /// These models are bandwidth-bound — every sampling step streams the whole
    /// checkpoint — so bandwidth predicts render time far better than core counts
    /// do. Taken from the chip tier rather than a table of exact figures per
    /// model: the tier is the dominant term, and a table of exact figures would be
    /// wrong for every chip released after this was written. It only has to be
    /// close: the estimate is shown as a wide range, and one finished render
    /// replaces it with a measurement anyway.
    static var memoryBandwidth: Double {
        if chipName.contains("Ultra") { return 800 }
        if chipName.contains("Max") { return 400 }
        if chipName.contains("Pro") { return 200 }
        // A base chip, or silicon this build has never heard of. Assuming the
        // slowest tier makes an unknown machine's estimate pessimistic rather
        // than wildly optimistic, which is the kinder way to be wrong.
        return 100
    }

    // MARK: - sysctl

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        // sysctl hands back a C string; drop the terminator before decoding.
        return String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
}
