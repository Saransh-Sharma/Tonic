//
//  MemoryReader.swift
//  Tonic
//
//  Memory data reader conforming to WidgetReader protocol
//  Follows Stats Master's Memory module pattern
//  Task ID: fn-5-v8r.4
//

import Foundation

/// Memory data reader conforming to WidgetReader protocol
/// Follows Stats Master's Memory module pattern
@MainActor
final class MemoryReader: WidgetReader {
    typealias Output = MemoryData

    let preferredInterval: TimeInterval = 2.0

    init() {}

    func read() async throws -> MemoryData {
        // Run on background thread for stats collection
        return await Task.detached {
            await self.getMemoryData()
        }.value
    }

    private func getMemoryData() async -> MemoryData {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryData(usedBytes: 0, totalBytes: 0, pressure: .normal)
        }

        let pageSize = UInt64(vm_kernel_page_size)

        // Calculate memory usage
        let used = (UInt64(stats.active_count) + UInt64(stats.wire_count)) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        // Get physical memory
        var memSize: Int = 0
        var memSizeLen = MemoryLayout<Int>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeLen, nil, 0)

        // Get swap usage
        var xswUsage = xsw_usage(xsu_total: 0, xsu_used: 0, xsu_pagesize: 0, xsu_encrypted: 0)
        var xswSize = MemoryLayout<xsw_usage>.stride
        sysctlbyname("vm.swapusage", &xswUsage, &xswSize, nil, 0)

        // Calculate memory pressure
        let free = UInt64(stats.free_count) * pageSize
        let total = UInt64(stats.wire_count + stats.active_count + stats.inactive_count + stats.free_count) * pageSize
        let freePercentage = total > 0 ? Double(free) / Double(total) : 0

        let pressure: MemoryPressure
        if freePercentage < 0.05 {
            pressure = .critical
        } else if freePercentage < 0.15 {
            pressure = .warning
        } else {
            pressure = .normal
        }

        let swapBytes = UInt64(xswUsage.xsu_used)

        return MemoryData(
            usedBytes: used,
            totalBytes: UInt64(memSize),
            pressure: pressure,
            compressedBytes: compressed,
            swapBytes: swapBytes
        )
    }
}

// MARK: - C Types

private struct xsw_usage {
    var xsu_total: UInt64
    var xsu_used: UInt64
    var xsu_pagesize: UInt32
    var xsu_encrypted: UInt32
}
