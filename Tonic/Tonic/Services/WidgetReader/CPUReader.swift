//
//  CPUReader.swift
//  Tonic
//
//  CPU data reader conforming to WidgetReader protocol
//  Follows Stats Master's CPU module reader pattern
//  Task ID: fn-5-v8r.4
//

import Foundation

/// CPU data reader conforming to WidgetReader protocol
/// Follows Stats Master's CPU module reader pattern
@MainActor
final class CPUReader: WidgetReader {
    typealias Output = CPUData

    let preferredInterval: TimeInterval = 2.0

    private var previousCPUInfo: processor_info_array_t?
    private var previousNumCpuInfo: mach_msg_type_number_t = 0
    private var previousNumCPUs: UInt32 = 0
    private let cpuLock = NSLock()

    init() {}

    func read() async throws -> CPUData {
        // Run on background thread for CPU intensive work
        let (totalUsage, perCoreUsage) = await Task.detached {
            return await self.getCPUData()
        }.value

        return CPUData(
            totalUsage: totalUsage,
            perCoreUsage: perCoreUsage
        )
    }

    private func getCPUData() async -> (Double, [Double]) {
        var numCPUs: UInt32 = 0
        var numCpuInfo: mach_msg_type_number_t = 0
        var cpuInfo: processor_info_array_t?
        var numTotalCpu: UInt32 = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numTotalCpu,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return (0.0, [])
        }

        cpuLock.lock()
        defer { cpuLock.unlock() }

        // Calculate total usage
        var usage = 0.0
        if let prevInfo = previousCPUInfo, previousNumCPUs > 0 {
            let prevUser = prevInfo[Int(CPU_STATE_USER)]
            let prevSystem = prevInfo[Int(CPU_STATE_SYSTEM)]
            let prevIdle = prevInfo[Int(CPU_STATE_IDLE)]
            let prevNice = prevInfo[Int(CPU_STATE_NICE)]

            let currentUser = info[Int(CPU_STATE_USER)]
            let currentSystem = info[Int(CPU_STATE_SYSTEM)]
            let currentIdle = info[Int(CPU_STATE_IDLE)]
            let currentNice = info[Int(CPU_STATE_NICE)]

            let prevTotal = prevUser + prevSystem + prevIdle + prevNice
            let currentTotal = currentUser + currentSystem + currentIdle + currentNice

            let diffTotal = currentTotal - prevTotal
            let diffIdle = currentIdle - prevIdle

            if diffTotal > 0 {
                usage = (1.0 - Double(diffIdle) / Double(diffTotal)) * 100.0
            }
        }

        // Store current for next iteration
        if let prevInfo = previousCPUInfo {
            vm_deallocate(
                mach_task_self(),
                vm_address_t(UInt(bitPattern: prevInfo)),
                vm_size_t(Int(previousNumCpuInfo) * MemoryLayout<integer_t>.size)
            )
        }

        previousCPUInfo = cpuInfo
        previousNumCpuInfo = numCpuInfo
        previousNumCPUs = numTotalCpu

        // Calculate per-core usage
        var coreUsages: [Double] = []
        let CPU_STATE_MAX = 4
        for i in 0..<Int(numTotalCpu) {
            let base = i * Int(CPU_STATE_MAX)

            let user = UInt32(info[base + Int(CPU_STATE_USER)])
            let system = UInt32(info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(info[base + Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice
            let coreUsage = total > 0 ? Double(user + system) / Double(total) * 100.0 : 0.0
            coreUsages.append(max(0, min(100, coreUsage)))
        }

        return (max(0, min(100, usage)), coreUsages)
    }
}
