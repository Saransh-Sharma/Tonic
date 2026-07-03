//
//  ProcessSampler.swift
//  Tonic
//
//  Per-process CPU and memory sampling via libproc — the first real process
//  data in the app (WidgetDataManager previously hardcoded topProcesses to
//  nil). Plain C calls, works sandboxed, no entitlements needed.
//
//  CPU% needs two samples: the sampler keeps each PID's cumulative CPU time
//  and computes the delta against the previous call. The first call therefore
//  reports 0% for everything; callers poll on an interval anyway.
//

import AppKit
import Darwin
import Foundation

final class ProcessSampler: @unchecked Sendable {

    static let shared = ProcessSampler()

    private let lock = NSLock()
    /// PID → (cumulative CPU ns, sample timestamp) from the previous pass.
    private var previousCPUTime: [pid_t: (cpuNanos: UInt64, timestamp: TimeInterval)] = [:]

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    struct Sample: Sendable {
        let pid: pid_t
        let name: String
        let cpuPercent: Double
        let memoryBytes: UInt64
    }

    // MARK: - Sampling

    /// One pass over all visible processes. Ordered by CPU descending.
    func sample() -> [Sample] {
        // Enumerate PIDs.
        var pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(pidCount) + 32)
        pidCount = proc_listallpids(&pids, Int32(pids.count) * Int32(MemoryLayout<pid_t>.size))
        guard pidCount > 0 else { return [] }

        let now = ProcessInfo.processInfo.systemUptime
        var samples: [Sample] = []
        var nextCPUTime: [pid_t: (cpuNanos: UInt64, timestamp: TimeInterval)] = [:]

        lock.lock()
        let previous = previousCPUTime
        lock.unlock()

        for pid in pids.prefix(Int(pidCount)) where pid > 0 {
            var usage = rusage_info_current()
            let result = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            }
            guard result == 0 else { continue }

            let machTime = usage.ri_user_time &+ usage.ri_system_time
            let cpuNanos = machTime &* UInt64(Self.timebase.numer) / UInt64(Self.timebase.denom)
            nextCPUTime[pid] = (cpuNanos, now)

            var cpuPercent = 0.0
            if let prev = previous[pid], cpuNanos >= prev.cpuNanos, now > prev.timestamp {
                let deltaNanos = Double(cpuNanos - prev.cpuNanos)
                let deltaWall = (now - prev.timestamp) * 1_000_000_000
                cpuPercent = min((deltaNanos / deltaWall) * 100, 100 * Double(ProcessInfo.processInfo.activeProcessorCount))
            }

            samples.append(Sample(
                pid: pid,
                name: Self.processName(for: pid),
                cpuPercent: cpuPercent,
                memoryBytes: usage.ri_phys_footprint
            ))
        }

        lock.lock()
        previousCPUTime = nextCPUTime
        lock.unlock()

        return samples.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// Top consumers as the ProcessUsage model used by Monitor UI.
    func topByCPU(limit: Int = 10) -> [ProcessUsage] {
        sample().prefix(limit).map { sample in
            ProcessUsage(
                id: sample.pid,
                name: sample.name,
                cpuUsage: sample.cpuPercent,
                memoryUsage: sample.memoryBytes
            )
        }
    }

    /// Top memory consumers as the AppResourceUsage model used by memory data.
    func topByMemory(limit: Int = 5) -> [AppResourceUsage] {
        sample()
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(limit)
            .map { AppResourceUsage(name: $0.name, cpuUsage: $0.cpuPercent, memoryBytes: $0.memoryBytes) }
    }

    // MARK: - Termination

    enum KillResult {
        case terminated
        case notPermitted
        case failed(errno: Int32)
    }

    /// Polite SIGTERM. Other users' and system processes fail gracefully.
    func terminate(pid: pid_t) -> KillResult {
        guard kill(pid, SIGTERM) == 0 else {
            let code = errno
            return code == EPERM ? .notPermitted : .failed(errno: code)
        }
        return .terminated
    }

    // MARK: - Names

    private static func processName(for pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if proc_pidpath(pid, &buffer, UInt32(MAXPATHLEN)) > 0 {
            let path = String(cString: buffer)
            if !path.isEmpty {
                return (path as NSString).lastPathComponent
            }
        }
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if proc_name(pid, &nameBuffer, UInt32(MAXPATHLEN)) > 0 {
            return String(cString: nameBuffer)
        }
        return "pid \(pid)"
    }
}
