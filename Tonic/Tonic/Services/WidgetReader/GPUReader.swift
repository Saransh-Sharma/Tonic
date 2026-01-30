//
//  GPUReader.swift
//  Tonic
//
//  GPU data reader conforming to WidgetReader protocol
//  Apple Silicon only - uses IOAccelerator/IOGPU
//  Task ID: fn-5-v8r.6
//

import Foundation
import IOKit
import IOKit.graphics

/// GPU data reader conforming to WidgetReader protocol
/// Apple Silicon only - uses IOAccelerator for GPU stats
@MainActor
final class GPUReader: WidgetReader {
    typealias Output = GPUData

    let preferredInterval: TimeInterval = 2.0

    private var previousStats: (usedMemory: UInt64, timestamp: Date)?

    init() {}

    func read() async throws -> GPUData {
        #if arch(arm64)
        // Run on background thread for IOKit calls
        return await Task.detached {
            self.getGPUData()
        }.value
        #else
        // Intel Macs - GPU monitoring not fully supported
        return GPUData(timestamp: Date())
        #endif
    }

    #if arch(arm64)
    private func getGPUData() -> GPUData {
        var usage: Double? = nil
        var usedMemory: UInt64? = nil
        var totalMemory: UInt64? = nil
        var temperature: Double? = nil

        // Get total unified memory available to GPU
        if let physMemory = getPhysicalMemory() {
            // On Apple Silicon, GPU can access all unified memory
            // Reserve some for system (typically 2-3GB)
            let gpuAccessibleMemory = physMemory - (2 * 1024 * 1024 * 1024) // Reserve 2GB
            totalMemory = gpuAccessibleMemory
        }

        // Try to get GPU activity from IORegistry
        // Apple AGX GPU registers under IOService:/AppleARMIODevice/AGX
        let gpuService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOGPU"))
        if gpuService != 0 {
            if let properties = IORegistryEntryCreateCFProperty(
                gpuService,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] {
                if let activity = properties["ActivityLevel"] as? Double {
                    usage = activity * 100
                }
            }
            IOObjectRelease(gpuService)
        }

        // Alternative: Try IOAccelerator
        if usage == nil {
            var iterator: io_iterator_t = 0
            if IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching("IOAccelerator"),
                &iterator
            ) == KERN_SUCCESS {
                while true {
                    let service = IOIteratorNext(iterator)
                    guard service != 0 else { break }

                    // Check if this is an Apple GPU
                    if let name = IORegistryEntryCreateCFProperty(
                        service,
                        "IOName" as CFString,
                        kCFAllocatorDefault,
                        0
                    )?.takeRetainedValue() as? String,
                       name.contains("AGX") || name.contains("AppleGPU") {
                        // Try to get performance statistics
                        if let stats = IORegistryEntryCreateCFProperty(
                            service,
                            "PerformanceStatistics" as CFString,
                            kCFAllocatorDefault,
                            0
                        )?.takeRetainedValue() as? [String: Any] {
                            if let deviceUtil = stats["DeviceUtilization"] as? Double {
                                usage = deviceUtil * 100
                            } else if let activity = stats["ActivityLevel"] as? Double {
                                usage = activity * 100
                            }
                        }
                    }

                    IOObjectRelease(service)
                }
                IOObjectRelease(iterator)
            }
        }

        // Try to get GPU temperature from IOPM (power management)
        temperature = getGPUTemperature()

        // Estimate GPU memory usage
        if let total = totalMemory {
            // Estimate GPU memory based on activity
            // On unified memory, GPU typically uses 5-15% when idle
            let estimatedGPUMemoryPercent = usage ?? 10.0
            usedMemory = UInt64(Double(total) * (estimatedGPUMemoryPercent / 100.0))
        }

        return GPUData(
            usagePercentage: usage,
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            temperature: temperature,
            timestamp: Date()
        )
    }

    private func getPhysicalMemory() -> UInt64? {
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        guard sysctl(&mib, UInt32(mib.count), &size, &len, nil, 0) == 0 else { return nil }
        return size
    }

    private func getGPUTemperature() -> Double? {
        // Try to get GPU temperature from thermal zones
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOThermalPlane"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        // Apple Silicon thermal zones for GPU
        let gpuThermalKeys = [
            "TG0E", // GPU thermal zone
            "TG0P", // GPU prox
            "TG0D"  // GPU die
        ]

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }

            for key in gpuThermalKeys {
                if let tempValue = IORegistryEntryCreateCFProperty(
                    service,
                    key as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? Int {
                    IOObjectRelease(service)
                    // Temperature is typically in deci-degrees
                    return Double(tempValue) / 100.0
                }
            }

            IOObjectRelease(service)
        }

        return nil
    }
    #endif
}

// MARK: - Constants

private let CTL_HW = 6
private let HW_MEMSIZE = 24
