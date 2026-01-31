//
//  MemoryReader.swift
//  Tonic
//
//  Memory data reader conforming to WidgetReader protocol
//  Follows Stats Master's Memory module pattern
//  Task ID: fn-5-v8r.4, fn-6-i4g.5
//

import Foundation
import AppKit

/// Memory data reader conforming to WidgetReader protocol
/// Follows Stats Master's Memory module pattern with enhanced data collection
/// Includes: swap details, pressure levels, and top memory-consuming processes
@MainActor
final class MemoryReader: WidgetReader {
    typealias Output = MemoryData

    let preferredInterval: TimeInterval = 2.0

    // Process list caching (to avoid frequent process spawning)
    private var cachedTopProcesses: [AppResourceUsage]?
    private var lastProcessFetchDate: Date?
    private let processCacheInterval: TimeInterval = 2.0
    private let maxProcesses: Int = 8

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

        // Calculate memory usage following Stats Master's formula
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let external = UInt64(stats.external_page_count) * pageSize

        // Stats Master formula: used = active + inactive + speculative + wired + compressed - purgeable - external
        let used = active + inactive + speculative + wired + compressed - purgeable - external

        // Get physical memory
        var memSize: Int = 0
        var memSizeLen = MemoryLayout<Int>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeLen, nil, 0)
        let totalBytes = UInt64(memSize)

        // Calculate free memory
        let freeBytes = totalBytes > used ? totalBytes - used : 0

        // Get swap usage via vm.swapusage sysctl
        let (swapTotal, swapUsed) = getSwapUsage()
        let swapBytes = swapUsed ?? 0

        // Get actual kernel memory pressure level via sysctl
        // Stats Master pattern: kern.memorystatus_vm_pressure_level returns 0-4
        // 0/1 = normal, 2 = warning, 4 = critical
        let (pressure, pressureLevel) = getKernelMemoryPressure()

        // Map pressure to 0-100 scale based on kernel level and free percentage
        let freePercentage = totalBytes > 0 ? Double(freeBytes) / Double(totalBytes) : 0
        let pressureValue = mapPressureToScale(level: pressureLevel, freePercentage: freePercentage)

        // Get top memory-consuming processes via top command
        let topProcesses = await getTopMemoryProcesses()

        return MemoryData(
            usedBytes: used,
            totalBytes: totalBytes,
            pressure: pressure,
            compressedBytes: compressed,
            swapBytes: swapBytes,
            freeBytes: freeBytes,
            swapTotalBytes: swapTotal,
            swapUsedBytes: swapUsed,
            pressureValue: pressureValue,
            topProcesses: topProcesses
        )
    }

    // MARK: - Enhanced Swap Reader

    /// Get detailed swap usage information via vm.swapusage sysctl
    /// Returns (totalBytes, usedBytes)
    private func getSwapUsage() -> (total: UInt64?, used: UInt64?) {
        var xswUsage = xsw_usage(xsu_total: 0, xsu_used: 0, xsu_pagesize: 0, xsu_encrypted: 0)
        var xswSize = MemoryLayout<xsw_usage>.stride

        guard sysctlbyname("vm.swapusage", &xswUsage, &xswSize, nil, 0) == 0 else {
            return (nil, nil)
        }

        // xsw_usage structure provides:
        // - xsu_total: total swap space in bytes
        // - xsu_used: used swap space in bytes
        // - xsu_pagesize: page size (for reference)
        return (UInt64(xswUsage.xsu_total), UInt64(xswUsage.xsu_used))
    }

    // MARK: - Kernel Memory Pressure

    /// Get actual kernel memory pressure level via kern.memorystatus_vm_pressure_level
    /// Stats Master pattern: returns 0-4 where 0/1=normal, 2=warning, 4=critical
    private func getKernelMemoryPressure() -> (pressure: MemoryPressure, level: Int) {
        var pressureLevel: Int = 0
        var intSize: size_t = MemoryLayout<Int>.size

        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &intSize, nil, 0)

        guard result == 0 else {
            // Fallback to normal if sysctl fails
            return (.normal, 0)
        }

        // Map kernel pressure level to MemoryPressure enum
        // Stats Master: 2 = warning, 4 = critical, default = normal
        let pressure: MemoryPressure
        switch pressureLevel {
        case 2:
            pressure = .warning
        case 4:
            pressure = .critical
        default:
            pressure = .normal
        }

        return (pressure, pressureLevel)
    }

    /// Map memory pressure to a 0-100 scale
    /// - 0-33: Normal (low pressure)
    /// - 34-66: Warning (moderate pressure)
    /// - 67-100: Critical (high pressure)
    private func mapPressureToScale(level: Int, freePercentage: Double) -> Double {
        switch level {
        case 0, 1:
            // Normal: 0-33, inversely proportional to free memory
            // More free memory = lower pressure value
            let normalizedFree = min(1.0, max(0.0, freePercentage))
            return (1.0 - normalizedFree) * 33.0
        case 2:
            // Warning: 34-66
            // Use free percentage to position within warning range
            let normalizedFree = min(0.15, max(0.0, freePercentage))
            return 34.0 + (1.0 - normalizedFree / 0.15) * 32.0
        case 4:
            // Critical: 67-100
            // Use free percentage to position within critical range
            let normalizedFree = min(0.05, max(0.0, freePercentage))
            return 67.0 + (1.0 - normalizedFree / 0.05) * 33.0
        default:
            // Unknown level, treat as normal
            return (1.0 - min(1.0, freePercentage)) * 33.0
        }
    }

    // MARK: - Process Memory Reader

    /// Get top memory-consuming processes via top command (Stats Master pattern)
    /// Uses caching to avoid frequent process spawning
    private func getTopMemoryProcesses() async -> [AppResourceUsage]? {
        // Check cache first
        let now = Date()
        if let cachedDate = lastProcessFetchDate,
           now.timeIntervalSince(cachedDate) < processCacheInterval,
           let cached = cachedTopProcesses {
            return cached
        }

        // Use top command following Stats Master pattern
        // top -l 1 -o mem -n <count> -stats pid,command,mem
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "1", "-o", "mem", "-n", "\(maxProcesses)", "-stats", "pid,command,mem"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: outputData, encoding: .utf8),
                  task.terminationStatus == 0 else {
                return nil
            }

            let processes = parseTopOutput(output)
            lastProcessFetchDate = now
            cachedTopProcesses = processes
            return processes
        } catch {
            return nil
        }
    }

    /// Parse top command output to extract process info
    /// Stats Master pattern: matches lines like "12345* processname 100M"
    private func parseTopOutput(_ output: String) -> [AppResourceUsage]? {
        var processes: [AppResourceUsage] = []

        output.enumerateLines { line, stop in
            // Stats Master regex: "^\\d+\\** +.* +\\d+[A-Z]*\\+?\\-? *$"
            // Match lines that start with PID and end with memory size
            guard self.lineMatchesProcessPattern(line) else { return }

            if let process = self.parseProcessLine(line) {
                processes.append(process)
            }

            if processes.count >= self.maxProcesses {
                stop = true
            }
        }

        return processes.isEmpty ? nil : processes
    }

    /// Check if line matches the process output pattern
    private func lineMatchesProcessPattern(_ line: String) -> Bool {
        // Pattern: starts with digits, ends with memory size (digits followed by K/M/G)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        // Check if line starts with a number (PID)
        guard let firstChar = trimmed.first, firstChar.isNumber else { return false }

        // Check if line ends with memory size pattern (digits + optional suffix)
        let pattern = "\\d+[KMG]?\\+?\\-?\\s*$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            return regex.firstMatch(in: trimmed, options: [], range: range) != nil
        }

        return false
    }

    /// Parse a single process line from top output
    /// Format: "PID[*] COMMAND MEM" where MEM is like "100M", "1G", "500K"
    private func parseProcessLine(_ line: String) -> AppResourceUsage? {
        var str = line.trimmingCharacters(in: .whitespaces)

        // Extract PID (first numeric sequence)
        guard let pidMatch = str.range(of: "^\\d+", options: .regularExpression) else { return nil }
        let pidString = String(str[pidMatch])
        guard let pid = Int32(pidString) else { return nil }

        // Remove PID and any asterisk marker
        str = String(str[pidMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("*") {
            str = String(str.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Split remaining into parts
        var parts = str.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        // Last part is memory usage
        let memString = String(parts.removeLast())

        // Remaining parts form the command name
        let command = parts.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " +", with: "", options: .regularExpression)
            .replacingOccurrences(of: " -", with: "", options: .regularExpression)

        // Parse memory value (convert to bytes)
        let memoryBytes = parseMemoryString(memString)

        // Try to get app name from NSRunningApplication
        var name = command
        if let app = NSRunningApplication(processIdentifier: pid),
           let appName = app.localizedName {
            name = appName
        }

        // Try to get app icon
        let icon = getAppIcon(for: pid, name: name)

        return AppResourceUsage(
            name: name.isEmpty ? "Unknown" : name,
            bundleIdentifier: nil,
            icon: icon,
            cpuUsage: 0,
            memoryBytes: memoryBytes
        )
    }

    /// Parse memory string like "100M", "1G", "500K" to bytes
    private func parseMemoryString(_ str: String) -> UInt64 {
        let cleaned = str.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard !cleaned.isEmpty else { return 0 }

        // Get last character and check if it's a unit suffix
        guard let lastCharacter = cleaned.last else { return 0 }
        let lastChar = lastCharacter.uppercased()

        // Determine if last character is numeric or a unit suffix
        let hasUnitSuffix = !lastCharacter.isNumber
        let numericString: String
        if hasUnitSuffix {
            numericString = String(cleaned.dropLast())
        } else {
            numericString = cleaned
        }

        guard let value = Double(numericString) else { return 0 }

        if hasUnitSuffix {
            switch lastChar {
            case "G":
                return UInt64(value * 1024 * 1024 * 1024)
            case "M":
                return UInt64(value * 1024 * 1024)
            case "K":
                return UInt64(value * 1024)
            default:
                // Unknown suffix, assume megabytes
                return UInt64(value * 1024 * 1024)
            }
        } else {
            // No suffix, assume megabytes (top default)
            return UInt64(value * 1024 * 1024)
        }
    }

    /// Get app icon for a process
    private func getAppIcon(for pid: Int32, name: String) -> NSImage? {
        // Try to get icon from running application
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.icon
        }

        // Fallback: try to find app in /Applications
        let appPaths = [
            "/Applications/\(name).app",
            "/System/Applications/\(name).app",
            "/Applications/Utilities/\(name).app"
        ]

        for path in appPaths {
            if let bundle = Bundle(path: path),
               let iconFile = bundle.infoDictionary?["CFBundleIconFile"] as? String {
                let iconName = iconFile.replacingOccurrences(of: ".icns", with: "")
                if let iconPath = bundle.path(forResource: iconName, ofType: "icns") {
                    return NSImage(contentsOfFile: iconPath)
                }
            }
        }

        return nil
    }
}

// MARK: - C Types

private struct xsw_usage {
    var xsu_total: UInt64
    var xsu_used: UInt64
    var xsu_pagesize: UInt32
    var xsu_encrypted: UInt32
}
