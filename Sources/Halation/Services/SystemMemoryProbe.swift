import Darwin
import Foundation
import IOKit

/// One second's worth of where the machine's memory has gone.
///
/// The four bands add up to what macOS calls "Memory Used"; `swap` is separate
/// because it is not memory at all, it is what would not fit.
struct MemorySample: Equatable, Sendable {
    /// This app's own footprint.
    var app: Int64 = 0
    /// Everything this app spawned: the MLX sidecar, the ComfyUI server and any
    /// children of theirs. Taken as the process tree minus ourselves, so it needs
    /// no cooperation from the backends and works while nothing is rendering.
    var engine: Int64 = 0
    /// The part of `engine` that is held on the GPU, reported by the engine
    /// itself — `mx.get_active_memory` plus its cache, or Torch's
    /// `driver_allocated_memory`.
    ///
    /// Carved *out* of `engine` rather than added to it. There is no graphics
    /// carve-out on Apple silicon to add: measured here, holding 4 GiB on the
    /// GPU raised ordinary memory used from 69.8 to 73.6 GB while the driver's
    /// own wired figure did not move. Every GPU byte is already in the owning
    /// process's footprint, so showing it as a separate band on top would count
    /// the same memory twice.
    var engineMetal: Int64 = 0
    /// Memory used, less this app and its engine. Includes the GPU driver's own
    /// wired mapping, which was its own band until it turned out to be about
    /// 2.4 GB — under half a row, so it could never light one.
    var systemAndOthers: Int64 = 0
    /// Swap in use, machine-wide.
    var swap: Int64 = 0

    var used: Int64 { app + engine + systemAndOthers }
}

enum SystemMemoryProbe {

    /// Reads one sample. Cheap enough for 1 Hz: three syscalls and one registry
    /// walk, all unprivileged — none of this needs `powermetrics` or an
    /// entitlement.
    /// - Parameter engineMetal: what the engine says it holds on the GPU. The
    ///   caller supplies it because only the engines can know, and they report
    ///   on their own schedules.
    static func sample(engineMetal: Int64) -> MemorySample {
        var s = MemorySample()
        s.app = ProcessMemory.ownFootprintBytes
        let tree = ProcessMemory.treeFootprintBytes(of: getpid()) ?? s.app
        s.engine = max(0, tree - s.app)
        // Clamped: the two figures come from different clocks, and a Metal
        // reading that arrives a moment after the footprint shrank must not
        // push the band past the process it belongs to.
        s.engineMetal = min(max(0, engineMetal), s.engine)
        s.engine -= s.engineMetal
        s.swap = swapUsedBytes()
        s.systemAndOthers = max(0, usedBytes() - s.app - s.engine - s.engineMetal)
        return s
    }

    /// What Activity Monitor calls "Memory Used": app memory, wired, compressed.
    ///
    /// Purgeable pages are subtracted because the system gives them up under
    /// pressure rather than swapping, which is exactly the distinction this
    /// chart is drawing.
    static func usedBytes() -> Int64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size
                                           / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        // `vm_kernel_page_size` is a mutable global, which Swift 6 will not let
        // a concurrent context touch. `host_page_size` asks the kernel instead.
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return 0 }
        let page = Int64(pageSize)
        let appMemory = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
        let wired = Int64(stats.wire_count)
        let compressed = Int64(stats.compressor_page_count)
        return max(0, (appMemory + wired + compressed) * page)
    }

    static func swapUsedBytes() -> Int64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return Int64(usage.xsu_used)
    }

    /// The GPU driver's wired allocation, summed over every accelerator.
    ///
    /// `IOAccelerator`'s `PerformanceStatistics` also carries utilisation
    /// percentages, should this chart ever want them — all readable without
    /// privileges, unlike the Neural Engine's, which need `powermetrics`.
    static func gpuWiredBytes() -> Int64 {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOAccelerator"),
                                           &iterator) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        var total: Int64 = 0
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &unmanaged,
                                                    kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = unmanaged?.takeRetainedValue() as? [String: Any],
                  let performance = properties["PerformanceStatistics"] as? [String: Any],
                  let inUse = performance["In use system memory"] as? Int64
            else { continue }
            total += inUse
        }
        return total
    }
}
