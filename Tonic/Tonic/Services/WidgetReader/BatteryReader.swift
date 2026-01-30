//
//  BatteryReader.swift
//  Tonic
//
//  Battery data reader conforming to WidgetReader protocol
//  Follows Stats Master's Battery module reader pattern
//  Task ID: fn-5-v8r.6
//

import Foundation
import IOKit.ps

/// Battery data reader conforming to WidgetReader protocol
/// Follows Stats Master's Battery module UsageReader pattern
@MainActor
final class BatteryReader: WidgetReader {
    typealias Output = BatteryData

    let preferredInterval: TimeInterval = 5.0

    init() {}

    func read() async throws -> BatteryData {
        // Run on background thread for IOKit calls
        return await Task.detached {
            self.getBatteryData()
        }.value
    }

    private func getBatteryData() -> BatteryData {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFDictionary]

        guard let powerSources = sources else {
            return BatteryData(isPresent: false)
        }

        for source in powerSources {
            let info = source as NSDictionary

            guard let type = info[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else {
                continue
            }

            let isPresent = info[kIOPSIsPresentKey] as? Bool ?? true
            guard isPresent else {
                return BatteryData(isPresent: false)
            }

            let currentState = info[kIOPSPowerSourceStateKey] as? String
            let isCharging = currentState == kIOPSACPowerValue
            let isCharged = info[kIOPSIsChargedKey] as? Bool ?? false

            let capacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 100

            let timeToEmpty = info[kIOPSTimeToEmptyKey] as? Int

            // Battery health calculation
            let designCapacity = info[kIOPSDesignCapacityKey] as? Int
            let health: BatteryHealth
            if let design = designCapacity, design > 0 {
                let healthPercent = Double(maxCapacity) / Double(design) * 100
                if healthPercent > 80 {
                    health = .good
                } else if healthPercent > 60 {
                    health = .fair
                } else {
                    health = .poor
                }
            } else {
                health = .unknown
            }

            // Get cycle count via IOKit
            let cycleCount = getBatteryCycleCount()
            // Get temperature via IOKit
            let temperature = getBatteryTemperature()

            return BatteryData(
                isPresent: true,
                isCharging: isCharging,
                isCharged: isCharged,
                chargePercentage: Double(capacity),
                estimatedMinutesRemaining: timeToEmpty,
                health: health,
                cycleCount: cycleCount,
                temperature: temperature
            )
        }

        return BatteryData(isPresent: false)
    }

    // MARK: - Private Methods

    private func getBatteryCycleCount() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let properties = IORegistryEntryCreateCFProperty(
            service,
            "DesignCycleCount9C" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }

        return properties
    }

    private func getBatteryTemperature() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        // Temperature is typically in deci-degrees (divide by 10)
        guard let tempValue = IORegistryEntryCreateCFProperty(
            service,
            "Temperature" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }

        // Convert from deci-degrees Celsius to Celsius
        return Double(tempValue) / 100.0
    }
}

// MARK: - Battery Health Extension

public enum BatteryHealth: String, Sendable {
    case good
    case fair
    case poor
    case unknown

    public var description: String {
        switch self {
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - BatteryData Extension

public extension BatteryData {
    init(isPresent: Bool, isCharging: Bool = false, isCharged: Bool = false,
         chargePercentage: Double = 0, estimatedMinutesRemaining: Int? = nil,
         health: BatteryHealth = .unknown, cycleCount: Int? = nil, temperature: Double? = nil,
         timestamp: Date = Date()) {
        self.init(
            isPresent: isPresent,
            isCharging: isCharging,
            isCharged: isCharged,
            chargePercentage: chargePercentage,
            estimatedMinutesRemaining: estimatedMinutesRemaining,
            health: health,
            timestamp: timestamp
        )
    }

    var cycleCount: Int? { nil }
    var temperature: Double? { nil }
}
