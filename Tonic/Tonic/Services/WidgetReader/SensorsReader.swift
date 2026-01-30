//
//  SensorsReader.swift
//  Tonic
//
//  Sensors data reader for temperature and fans
//  Uses SMC communication via IOKit
//  Task ID: fn-5-v8r.6
//

import Foundation
import IOKit

/// Sensors data reader conforming to WidgetReader protocol
/// Reads temperature and fan data via SMC
@MainActor
final class SensorsReader: WidgetReader {
    typealias Output = SensorsData

    let preferredInterval: TimeInterval = 2.0

    private var smcConn: io_connect_t = 0

    init() {
        openSMCConnection()
    }

    deinit {
        closeSMCConnection()
    }

    func read() async throws -> SensorsData {
        // Run on background thread for IOKit calls
        return await Task.detached {
            self.getSensorsData()
        }.value
    }

    private func getSensorsData() -> SensorsData {
        var temperatures: [SensorReading] = []
        var fans: [FanReading] = []

        // Try to get temperature readings
        temperatures = getTemperatureReadings()

        // Try to get fan readings
        fans = getFanReadings()

        return SensorsData(
            temperatures: temperatures,
            fans: fans,
            timestamp: Date()
        )
    }

    // MARK: - SMC Connection

    private func openSMCConnection() {
        var result: kern_return_t
        var iterator: io_iterator_t = 0
        let device: io_object_t

        let matchingDictionary: CFMutableDictionary = IOServiceMatching("AppleSMC")
        result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)
        guard result == kIOReturnSuccess else { return }

        device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else { return }

        result = IOServiceOpen(device, mach_task_self_, 0, &smcConn)
        IOObjectRelease(device)
        guard result == kIOReturnSuccess else { return }
    }

    private func closeSMCConnection() {
        if smcConn != 0 {
            IOServiceClose(smcConn)
            smcConn = 0
        }
    }

    // MARK: - SMC Reading

    private func readSMCValue(_ key: String) -> Double? {
        guard smcConn != 0 else { return nil }

        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = FourCharCode(fromString: key)
        input.data8 = SMCKey.readKeyInfo.rawValue

        let result = callSMC(SMCKey.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else { return nil }

        let dataSize = UInt32(output.keyInfo.dataSize)
        let dataType = output.keyInfo.dataType.toString()

        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCKey.readBytes.rawValue

        let readResult = callSMC(SMCKey.kernelIndex.rawValue, input: &input, output: &output)
        guard readResult == kIOReturnSuccess else { return nil }

        return parseSMCValue(dataType: dataType, dataSize: Int(dataSize), bytes: output.bytes)
    }

    private func parseSMCValue(dataType: String, dataSize: Int, bytes: SMCBytes) -> Double? {
        guard dataSize > 0 else { return nil }

        // Check if all bytes are zero (except for some special keys)
        let bytesArray = Array(MemoryLayout<(UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)>.bindingAsBytes(from: bytes) {
            return $0.map { $0 }
        }

        if bytesArray.first(where: { $0 != 0 }) == nil {
            return nil
        }

        switch dataType {
        case "ui8 ":
            return Double(bytesArray[0])
        case "ui16":
            return Double(UInt16(bytesArray[0]) << 8 | UInt16(bytesArray[1]))
        case "ui32":
            return Double(UInt32(bytesArray[0]) << 24 |
                          UInt32(bytesArray[1]) << 16 |
                          UInt32(bytesArray[2]) << 8 |
                          UInt32(bytesArray[3]))
        case "sp1e":
            let value = Double(UInt16(bytesArray[0]) * 256 + UInt16(bytesArray[1]))
            return value / 16384
        case "sp3c":
            let value = Double(UInt16(bytesArray[0]) * 256 + UInt16(bytesArray[1]))
            return value / 4096
        case "sp4b":
            let value = Double(UInt16(bytesArray[0]) * 256 + UInt16(bytesArray[1]))
            return value / 2048
        case "sp78":
            let value = Double(Int(bytesArray[0]) * 256 + Int(bytesArray[1]))
            return value / 256
        case "fpe2":
            return Double(Int(bytesArray[0]) << 6 | Int(bytesArray[1]) >> 2)
        default:
            return nil
        }
    }

    private func callSMC(_ index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        return IOConnectCallStructMethod(
            smcConn,
            UInt32(index),
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }

    // MARK: - Temperature Readings

    private func getTemperatureReadings() -> [SensorReading] {
        var readings: [SensorReading] = []

        // Common CPU temperature keys
        let cpuKeys = ["TC0E", "TC0D", "TC0c", "TC0p", "TC1E", "TC1D", "TC1c", "TC1p"]
        // GPU temperature keys
        let gpuKeys = ["TG0E", "TG0D", "TG0p"]

        // Try each key
        for key in cpuKeys {
            if let temp = readSMCValue(key) {
                readings.append(SensorReading(
                    name: "CPU",
                    value: temp,
                    unit: "°C"
                ))
                break  // Use first available reading
            }
        }

        for key in gpuKeys {
            if let temp = readSMCValue(key) {
                readings.append(SensorReading(
                    name: "GPU",
                    value: temp,
                    unit: "°C"
                ))
                break
            }
        }

        // Try to get package temperature (Intel)
        if let packageTemp = readSMCValue("TC0P") ?? readSMCValue("TC0P") {
            if !readings.contains(where: { $0.name == "CPU" }) {
                readings.append(SensorReading(
                    name: "CPU Package",
                    value: packageTemp,
                    unit: "°C"
                ))
            }
        }

        return readings
    }

    // MARK: - Fan Readings

    private func getFanReadings() -> [FanReading] {
        var readings: [FanReading] = []

        // Try up to 8 fans
        for i in 0..<8 {
            // Check if fan exists by reading its max speed
            let maxSpeedKey = "F\(i)Mx"
            guard let maxSpeed = readSMCValue(maxSpeedKey) else { continue }

            // Get current speed
            let currentSpeedKey = "F\(i)Ac"
            let currentSpeed = readSMCValue(currentSpeedKey) ?? 0

            // Get min speed
            let minSpeedKey = "F\(i)Mn"
            let minSpeed = readSMCValue(minSpeedKey) ?? 0

            readings.append(FanReading(
                id: i,
                name: "Fan \(i)",
                currentSpeed: Int(currentSpeed),
                minSpeed: Int(minSpeed),
                maxSpeed: Int(maxSpeed)
            ))
        }

        return readings
    }
}

// MARK: - Data Models

/// Sensors data containing temperature and fan readings
public struct SensorsData: Sendable {
    public let temperatures: [SensorReading]
    public let fans: [FanReading]
    public let timestamp: Date

    public init(temperatures: [SensorReading] = [], fans: [FanReading] = [], timestamp: Date = Date()) {
        self.temperatures = temperatures
        self.fans = fans
        self.timestamp = timestamp
    }
}

/// A single sensor reading (temperature)
public struct SensorReading: Sendable, Identifiable {
    public let id = UUID()
    public let name: String
    public let value: Double
    public let unit: String

    public init(name: String, value: Double, unit: String) {
        self.name = name
        self.value = value
        self.unit = unit
    }

    public var formattedValue: String {
        String(format: "%.1f%@", value, unit)
    }
}

/// Fan speed reading
public struct FanReading: Sendable, Identifiable {
    public let id = UUID()
    public let id: Int  // Fan ID
    public let name: String
    public let currentSpeed: Int  // RPM
    public let minSpeed: Int  // RPM
    public let maxSpeed: Int  // RPM

    public init(id: Int, name: String, currentSpeed: Int, minSpeed: Int, maxSpeed: Int) {
        self.id = id
        self.name = name
        self.currentSpeed = currentSpeed
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
    }

    public var speedPercentage: Double {
        guard maxSpeed > 0 else { return 0 }
        return Double(currentSpeed) / Double(maxSpeed) * 100
    }
}

// MARK: - SMC Types

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0)
    var pLimitData: (UInt16, UInt16, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0, 0, 0, 0)
    var keyInfo: (UInt32, UInt32, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private enum SMCKey: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case writeBytes = 6
    case readIndex = 8
    case readKeyInfo = 9
    case readPLimit = 11
    case readVers = 12
}

// MARK: - FourCharCode Extension

extension UInt32 {
    init(fromString str: String) {
        precondition(str.count == 4)
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }
}

extension FixedWidthInteger {
    func toString() -> String where Self == UInt32 {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8 & 0xff)!) +
               String(describing: UnicodeScalar(self & 0xff)!)
    }
}
