//
//  SystemSnapshotProvider.swift
//  Tonic
//
//  Provider for Dashboard system specs snapshots.
//

import Foundation
import AppKit
import CoreGraphics
import IOKit
import Metal

enum SystemSnapshotProvider {
    static func fetch() throws -> SystemSnapshot {
        let modelIdentifier = Sysctl.string("hw.model") ?? "—"
        let deviceName = SystemSnapshotProvider.deviceDisplayName(modelIdentifier: modelIdentifier)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        let processorName = Sysctl.string("machdep.cpu.brand_string")
            ?? Sysctl.string("hw.model")
            ?? "Apple Silicon"
        let coreSummary = coreCountsSummary()
        let processorSummary = [processorName, coreSummary].filter { !$0.isEmpty }.joined(separator: " • ")

        let memBytes = Sysctl.uint64("hw.memsize") ?? 0
        let memorySummary = memBytes > 0 ? ByteCountFormatter.string(fromByteCount: Int64(memBytes), countStyle: .memory) : "—"

        let graphicsSummary = graphicsDeviceSummary()
        let diskSummary = bootDiskSummary()
        let displaySummary = primaryDisplaySummary()
        let serialNumber = platformSerialNumber()
        let uptimeSummary = uptimeString()

        return SystemSnapshot(
            deviceDisplayName: deviceName,
            osString: osString,
            processorSummary: processorSummary.isEmpty ? "—" : processorSummary,
            memorySummary: memorySummary,
            graphicsSummary: graphicsSummary,
            diskSummary: diskSummary,
            displaySummary: displaySummary,
            modelIdentifier: modelIdentifier,
            modelYear: nil,
            serialNumber: serialNumber,
            uptimeSummary: uptimeSummary
        )
    }

    private static func deviceDisplayName(modelIdentifier: String) -> String {
        return "Mac (\(modelIdentifier))"
    }

    private static func coreCountsSummary() -> String {
        let perf = Sysctl.int("hw.perflevel0.physicalcpu") ?? Sysctl.int("hw.perflevel0.logicalcpu")
        let eff = Sysctl.int("hw.perflevel1.physicalcpu") ?? Sysctl.int("hw.perflevel1.logicalcpu")
        let total = Sysctl.int("hw.ncpu") ?? Sysctl.int("hw.logicalcpu")

        var parts: [String] = []
        if let total, total > 0 {
            parts.append("\(total) cores")
        }
        if let eff, eff > 0 {
            parts.append("\(eff) efficiency")
        }
        if let perf, perf > 0 {
            parts.append("\(perf) performance")
        }
        return parts.joined(separator: " • ")
    }

    private static func graphicsDeviceSummary() -> String {
        if let device = MTLCreateSystemDefaultDevice() {
            return device.name
        }
        return "—"
    }

    private static func bootDiskSummary() -> String {
        let url = URL(fileURLWithPath: "/")
        do {
            let values = try url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let name = values.volumeName ?? "Macintosh HD"
            let total = values.volumeTotalCapacity ?? 0
            let available = values.volumeAvailableCapacity ?? 0
            let totalText = total > 0 ? ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file) : "—"
            let availText = available > 0 ? ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file) : "—"
            return "\(name) (\(totalText) • \(availText) free)"
        } catch {
            return "—"
        }
    }

    private static func primaryDisplaySummary() -> String {
        guard let screen = NSScreen.main else { return "—" }
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return "—"
        }

        let mode = CGDisplayCopyDisplayMode(id)
        let width = mode?.pixelWidth ?? Int(screen.frame.width * screen.backingScaleFactor)
        let height = mode?.pixelHeight ?? Int(screen.frame.height * screen.backingScaleFactor)
        let refresh = mode?.refreshRate ?? 0

        let sizeMM = CGDisplayScreenSize(id)
        let diagonalInches = sqrt(sizeMM.width * sizeMM.width + sizeMM.height * sizeMM.height) / 25.4
        let sizeText = diagonalInches.isFinite && diagonalInches > 1 ? String(format: "%.0f″", diagonalInches) : nil

        let isBuiltin = CGDisplayIsBuiltin(id) != 0
        let name = isBuiltin ? "Built‑in Display" : "Display"

        var parts: [String] = [name]
        if let sizeText {
            parts.append(sizeText)
        }
        parts.append("\(width)x\(height)")
        if refresh > 1 {
            parts.append("\(Int(refresh.rounded()))Hz")
        }
        return parts.joined(separator: " • ")
    }

    private static func uptimeString() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &bootTime, &size, nil, 0)

        let bootTimestamp = Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000.0
        let now = Date().timeIntervalSince1970
        let uptimeSeconds = max(0, now - bootTimestamp)

        let days = Int(uptimeSeconds) / (24 * 3600)
        let hours = (Int(uptimeSeconds) % (24 * 3600)) / 3600
        let minutes = (Int(uptimeSeconds) % 3600) / 60

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s"), \(hours) hour\(hours == 1 ? "" : "s")"
        }
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s"), \(minutes) min"
        }
        return "\(minutes) min"
    }

    private static func platformSerialNumber() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        if let serial = IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformSerialNumber" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return serial
        }

        return nil
    }
}

private enum Sysctl {
    static func string(_ name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var data = [CChar](repeating: 0, count: Int(size))
        guard sysctlbyname(name, &data, &size, nil, 0) == 0 else { return nil }
        return String(cString: data)
    }

    static func int(_ name: String) -> Int? {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    static func uint64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
