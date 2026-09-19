import Darwin
import Foundation

/// Resident memory of a process this user owns.
///
/// `proc_pid_rusage` needs no special entitlement for same-user processes, which
/// matters because the memory worth showing belongs to the backend — the Python
/// sidecar or the ComfyUI server — not to the app, which uses a few megabytes
/// while they hold tens of gigabytes.
enum ProcessMemory {
    static func residentBytes(of pid: pid_t) -> Int64? {
        guard pid > 0 else { return nil }
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        return Int64(info.ri_resident_size)
    }

    /// Physical memory installed, for context beside a usage figure.
    static var physicalBytes: Int64 { Int64(ProcessInfo.processInfo.physicalMemory) }
}
