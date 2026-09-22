import Darwin
import Foundation

/// Resident memory of processes this user owns.
///
/// `proc_pid_rusage` needs no special entitlement for same-user processes, which
/// matters because the memory worth showing belongs to the backend — the Python
/// sidecar or the ComfyUI server — not to the app, which holds a few hundred
/// megabytes while they hold tens of gigabytes.
enum ProcessMemory {

    /// What Activity Monitor calls Memory.
    ///
    /// `ri_phys_footprint`, and the choice is not cosmetic — it is the whole
    /// difference between a useful figure and a useless one. Measured on a live
    /// MLX render holding the 4-bit set:
    ///
    ///     ri_resident_size    0.25 GB
    ///     ri_phys_footprint   106.45 GB
    ///
    /// `ps` agrees with the first. MLX's unified-memory allocations do not
    /// appear in the resident size at all, so RSS reports the interpreter and
    /// nothing else. A plain `storageModeShared` Metal buffer *does* move both,
    /// which is what made the earlier diagnosis wrong: the test allocated memory
    /// a different way from the thing being diagnosed.
    static func footprintBytes(of pid: pid_t) -> Int64? {
        guard pid > 0 else { return nil }
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        return Int64(info.ri_phys_footprint)
    }

    /// A process and everything descended from it.
    ///
    /// Sampling one pid was measuring the wrong thing: the status bar reported a
    /// few hundred megabytes during a render that was holding ninety gigabytes,
    /// because the process we had a handle on is a supervisor and the tensors
    /// live in a child. Which process does the work differs by backend and can
    /// change with a dependency update, so the tree is summed rather than any
    /// one pid trusted.
    static func treeFootprintBytes(of root: pid_t) -> Int64? {
        guard root > 0 else { return nil }
        let parents = parentsByPID()
        var total = footprintBytes(of: root) ?? 0
        var counted: Set<pid_t> = [root]

        // Repeated passes rather than recursion: the table is unordered, so a
        // child can appear before its parent has been counted.
        var grew = true
        while grew {
            grew = false
            for (pid, parent) in parents where !counted.contains(pid) && counted.contains(parent) {
                counted.insert(pid)
                total += footprintBytes(of: pid) ?? 0
                grew = true
            }
        }
        return total
    }

    /// Every process this user can see, as pid → parent pid.
    private static func parentsByPID() -> [pid_t: pid_t] {
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&name, 4, nil, &size, nil, 0) == 0, size > 0 else { return [:] }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var table = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&name, 4, &table, &size, nil, 0) == 0 else { return [:] }

        // The second call can return fewer entries than the first reported.
        var map: [pid_t: pid_t] = [:]
        for entry in table.prefix(size / MemoryLayout<kinfo_proc>.stride) {
            let pid = entry.kp_proc.p_pid
            if pid > 0 { map[pid] = entry.kp_eproc.e_ppid }
        }
        return map
    }

    /// The highest footprint a process has reached in its lifetime.
    ///
    /// The kernel keeps this, which is better than sampling for it: a poll every
    /// two seconds misses a spike between samples, and this one cannot. On the
    /// render above it reported 120.14 GB against 106.45 GB current — so nearly
    /// 14 GB of the peak had already been released by the time anything looked.
    static func peakFootprintBytes(of pid: pid_t) -> Int64? {
        guard pid > 0 else { return nil }
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        return Int64(info.ri_lifetime_max_phys_footprint)
    }

    /// A process tree's lifetime peak, summed the same way as the current total.
    static func treePeakFootprintBytes(of root: pid_t) -> Int64? {
        guard root > 0 else { return nil }
        let parents = parentsByPID()
        var total = peakFootprintBytes(of: root) ?? 0
        var counted: Set<pid_t> = [root]
        var grew = true
        while grew {
            grew = false
            for (pid, parent) in parents where !counted.contains(pid) && counted.contains(parent) {
                counted.insert(pid)
                total += peakFootprintBytes(of: pid) ?? 0
                grew = true
            }
        }
        return total
    }

    /// This app's own footprint, which is the smaller half of the story.
    static var ownFootprintBytes: Int64 { footprintBytes(of: getpid()) ?? 0 }

    /// Physical memory installed, for context beside a usage figure.
    static var physicalBytes: Int64 { Int64(ProcessInfo.processInfo.physicalMemory) }
}
