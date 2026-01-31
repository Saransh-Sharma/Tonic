//
//  SMCReader.swift
//  Tonic
//
//  SMC (System Management Controller) reader for temperature, voltage, power, and fan sensors
//  Follows Stats Master's SMC implementation pattern
//  Task ID: fn-6-i4g.8
//

import Foundation
import IOKit

// MARK: - SMC Data Types

/// SMC data type identifiers for parsing values
private enum SMCDataType: String {
    case UI8 = "ui8 "
    case UI16 = "ui16"
    case UI32 = "ui32"
    case SP1E = "sp1e"
    case SP3C = "sp3c"
    case SP4B = "sp4b"
    case SP5A = "sp5a"
    case SPA5 = "spa5"
    case SP69 = "sp69"
    case SP78 = "sp78"
    case SP87 = "sp87"
    case SP96 = "sp96"
    case SPB4 = "spb4"
    case SPF0 = "spf0"
    case FLT = "flt "
    case FPE2 = "fpe2"
    case FP2E = "fp2e"
    case FDS = "{fds"
}

/// SMC command keys
private enum SMCKeys: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case writeBytes = 6
    case readIndex = 8
    case readKeyInfo = 9
    case readPLimit = 11
    case readVers = 12
}

// MARK: - SMC Structures

/// SMC key data structure for IOKit communication
private struct SMCKeyData {
    typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8)

    struct VersionInfo {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct LimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = VersionInfo()
    var pLimitData = LimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

/// SMC value container for reading
private struct SMCValue {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)

    init(_ key: String) {
        self.key = key
    }
}

// MARK: - SMC Reader

/// SMC (System Management Controller) reader for accessing hardware sensor data
/// Provides temperature, voltage, power, and fan readings via IOKit
public final class SMCReader: @unchecked Sendable {

    /// Shared singleton instance
    public static let shared = SMCReader()

    /// SMC connection handle
    private var connection: io_connect_t = 0

    /// Lock for thread-safe SMC access
    private let lock = NSLock()

    /// Whether SMC is available on this system
    public var isAvailable: Bool {
        return connection != 0
    }

    // MARK: - Initialization

    private init() {
        openConnection()
    }

    deinit {
        closeConnection()
    }

    /// Open connection to SMC service
    private func openConnection() {
        var result: kern_return_t
        var iterator: io_iterator_t = 0

        let matchingDictionary: CFMutableDictionary = IOServiceMatching("AppleSMC")
        result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)

        guard result == kIOReturnSuccess else {
            print("[SMCReader] Failed to get matching services: \(result)")
            return
        }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)

        guard device != 0 else {
            print("[SMCReader] No SMC device found")
            return
        }

        result = IOServiceOpen(device, mach_task_self_, 0, &connection)
        IOObjectRelease(device)

        guard result == kIOReturnSuccess else {
            print("[SMCReader] Failed to open SMC service: \(result)")
            return
        }
    }

    /// Close SMC connection
    private func closeConnection() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    // MARK: - Public API

    /// Get a numeric value from SMC for the given key
    /// - Parameter key: 4-character SMC key (e.g., "TC0P" for CPU temperature)
    /// - Returns: The value as Double, or nil if unavailable
    public func getValue(_ key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }

        guard connection != 0 else { return nil }

        var value = SMCValue(key)
        let result = read(&value)

        guard result == kIOReturnSuccess, value.dataSize > 0 else {
            return nil
        }

        // Check for all-zero values (except special keys)
        if value.bytes.first(where: { $0 != 0 }) == nil &&
           value.key != "FS! " && value.key != "F0Md" && value.key != "F1Md" {
            return nil
        }

        return parseValue(value)
    }

    /// Get a string value from SMC for the given key
    /// - Parameter key: 4-character SMC key (e.g., "F0ID" for fan name)
    /// - Returns: The value as String, or nil if unavailable
    public func getStringValue(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard connection != 0 else { return nil }

        var value = SMCValue(key)
        let result = read(&value)

        guard result == kIOReturnSuccess, value.dataSize > 0 else {
            return nil
        }

        if value.bytes.first(where: { $0 != 0 }) == nil {
            return nil
        }

        guard value.dataType == SMCDataType.FDS.rawValue else {
            return nil
        }

        // Extract string from FDS data type (bytes 4-15)
        var chars: [Character] = []
        for i in 4...15 {
            if value.bytes[i] != 0 {
                chars.append(Character(UnicodeScalar(value.bytes[i])))
            }
        }
        return String(chars).trimmingCharacters(in: .whitespaces)
    }

    /// Get all available SMC keys
    /// - Returns: Array of 4-character SMC keys
    public func getAllKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }

        guard connection != 0 else { return [] }

        guard let keysCount = getValue("#KEY") else {
            return []
        }

        var keys: [String] = []
        var input = SMCKeyData()
        var output = SMCKeyData()

        for i in 0..<Int(keysCount) {
            input = SMCKeyData()
            output = SMCKeyData()

            input.data8 = SMCKeys.readIndex.rawValue
            input.data32 = UInt32(i)

            let result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
            if result == kIOReturnSuccess {
                keys.append(output.key.fourCharCodeToString())
            }
        }

        return keys
    }

    // MARK: - Sensor Reading Methods

    /// Read all temperature sensors
    /// - Returns: Array of temperature sensor readings
    public func readTemperatures() -> [SensorReading] {
        var readings: [SensorReading] = []

        // Known CPU temperature keys for different Mac generations
        let cpuKeys = [
            ("TC0C", "CPU Core"),
            ("TC0D", "CPU Die"),
            ("TC0P", "CPU Proximity"),
            ("TC0E", "CPU Core 1"),
            ("TC1E", "CPU Core 2"),
            ("TC2E", "CPU Core 3"),
            ("TC3E", "CPU Core 4"),
            ("TC4E", "CPU Core 5"),
            ("TC5E", "CPU Core 6"),
            ("TC6E", "CPU Core 7"),
            ("TC7E", "CPU Core 8"),
            ("Tc0p", "CPU Proximity"),
            ("TCXC", "CPU PECI"),
            ("TCMX", "CPU Max PECI"),
        ]

        // GPU temperature keys
        let gpuKeys = [
            ("TG0D", "GPU Die"),
            ("TG0P", "GPU Proximity"),
            ("TG0E", "GPU Core"),
            ("TGDD", "GPU Die"),
        ]

        // SOC temperature keys (Apple Silicon)
        let socKeys = [
            ("Tp01", "SOC 1"),
            ("Tp02", "SOC 2"),
            ("Tp03", "SOC 3"),
            ("Tp09", "SOC MTR 1"),
            ("Tp0T", "SOC MTR 2"),
        ]

        // Other temperature keys
        let otherKeys = [
            ("TA0P", "Ambient"),
            ("TA1P", "Ambient 2"),
            ("TB0T", "Battery"),
            ("TH0A", "Heatsink A"),
            ("TH0B", "Heatsink B"),
            ("TM0P", "Memory Proximity"),
            ("TM0S", "Memory Slot"),
            ("Ts0P", "Palm Rest"),
            ("Ts0S", "Memory Bank Proximity"),
        ]

        // Collect readings from all key groups
        for (key, name) in cpuKeys {
            if let value = getValue(key), value > 0 && value < 120 {
                readings.append(SensorReading(
                    id: key,
                    name: name,
                    value: value,
                    unit: "C"
                ))
            }
        }

        for (key, name) in gpuKeys {
            if let value = getValue(key), value > 0 && value < 120 {
                readings.append(SensorReading(
                    id: key,
                    name: name,
                    value: value,
                    unit: "C"
                ))
            }
        }

        for (key, name) in socKeys {
            if let value = getValue(key), value > 0 && value < 120 {
                readings.append(SensorReading(
                    id: key,
                    name: name,
                    value: value,
                    unit: "C"
                ))
            }
        }

        for (key, name) in otherKeys {
            if let value = getValue(key), value > 0 && value < 120 {
                readings.append(SensorReading(
                    id: key,
                    name: name,
                    value: value,
                    unit: "C"
                ))
            }
        }

        return readings
    }

    /// Read all voltage sensors
    /// - Returns: Array of voltage sensor readings
    public func readVoltages() -> [SensorReading] {
        var readings: [SensorReading] = []

        let voltageKeys = [
            ("VC0C", "CPU Core"),
            ("VC1C", "CPU Core 2"),
            ("VG0C", "GPU Core"),
            ("VD0R", "DC In"),
            ("VBAT", "Battery"),
            ("VP0R", "12V Rail"),
            ("VN0C", "Memory"),
            ("Vp0C", "12V Rail 2"),
        ]

        for (key, name) in voltageKeys {
            if let value = getValue(key), value >= 0 && value < 300 {
                readings.append(SensorReading(
                    id: key,
                    name: name,
                    value: value,
                    unit: "V"
                ))
            }
        }

        return readings
    }

    /// Read all power sensors
    /// - Returns: Array of power sensor readings
    public func readPower() -> [SensorReading] {
        var readings: [SensorReading] = []

        let powerKeys = [
            ("PC0C", "CPU Core"),
            ("PC0R", "CPU Package"),
            ("PCPC", "CPU Package Total"),
            ("PCPG", "CPU Cores"),
            ("PG0R", "GPU"),
            ("PSTR", "System Total"),
            ("PDTR", "DC In"),
            ("PBAT", "Battery"),
            ("PMEM", "Memory"),
        ]

        for (key, name) in powerKeys {
            if let value = getValue(key), value >= 0 && value < 500 {
                readings.append(SensorReading(
                    id: key,
                    name: name,
                    value: value,
                    unit: "W"
                ))
            }
        }

        return readings
    }

    /// Read all fan sensors
    /// - Returns: Array of fan readings with RPM, min, max, and mode
    public func readFans() -> [FanReading] {
        var fans: [FanReading] = []

        // Get fan count
        guard let fanCount = getValue("FNum"), fanCount > 0 else {
            return fans
        }

        for i in 0..<Int(fanCount) {
            // Get current RPM
            let currentKey = "F\(i)Ac"
            guard let currentRPM = getValue(currentKey) else { continue }

            // Get min RPM
            let minKey = "F\(i)Mn"
            let minRPM = getValue(minKey).map { Int($0) }

            // Get max RPM
            let maxKey = "F\(i)Mx"
            let maxRPM = getValue(maxKey).map { Int($0) }

            // Get fan name
            let nameKey = "F\(i)ID"
            var name = getStringValue(nameKey)

            // Default names for left/right fans
            if name == nil && Int(fanCount) == 2 {
                name = i == 0 ? "Left Fan" : "Right Fan"
            }

            // Get fan mode
            let mode = getFanMode(i)

            fans.append(FanReading(
                id: currentKey,
                name: name ?? "Fan \(i + 1)",
                rpm: Int(currentRPM),
                minRPM: minRPM,
                maxRPM: maxRPM,
                mode: mode
            ))
        }

        return fans
    }

    /// Get the operating mode for a fan
    private func getFanMode(_ fanId: Int) -> FanMode {
        // Try per-fan mode key first
        if let modeValue = getValue("F\(fanId)Md") {
            switch Int(modeValue) {
            case 0: return .automatic
            case 1: return .forced
            default: return .unknown
            }
        }

        // Check global fans mode
        let globalMode = Int(getValue("FS! ") ?? 0)

        switch globalMode {
        case 0:
            return .automatic
        case 3:
            return .forced
        case 1 where fanId == 0:
            return .forced
        case 2 where fanId == 1:
            return .forced
        default:
            return .automatic
        }
    }

    // MARK: - Private Methods

    /// Read value from SMC
    private func read(_ value: inout SMCValue) -> kern_return_t {
        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = FourCharCode(fromString: value.key)
        input.data8 = SMCKeys.readKeyInfo.rawValue

        var result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return result
        }

        value.dataSize = UInt32(output.keyInfo.dataSize)
        value.dataType = output.keyInfo.dataType.fourCharCodeToString()
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCKeys.readBytes.rawValue

        result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return result
        }

        // Copy bytes from output
        withUnsafePointer(to: output.bytes) { bytesPtr in
            bytesPtr.withMemoryRebound(to: UInt8.self, capacity: 32) { ptr in
                for i in 0..<min(32, Int(value.dataSize)) {
                    value.bytes[i] = ptr[i]
                }
            }
        }

        return kIOReturnSuccess
    }

    /// Call SMC with input/output structures
    private func call(_ index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        return IOConnectCallStructMethod(
            connection,
            UInt32(index),
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }

    /// Parse SMC value based on data type
    private func parseValue(_ value: SMCValue) -> Double? {
        switch value.dataType {
        case SMCDataType.UI8.rawValue:
            return Double(value.bytes[0])

        case SMCDataType.UI16.rawValue:
            return Double(UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1]))

        case SMCDataType.UI32.rawValue:
            return Double(UInt32(value.bytes[0]) << 24 |
                         UInt32(value.bytes[1]) << 16 |
                         UInt32(value.bytes[2]) << 8 |
                         UInt32(value.bytes[3]))

        case SMCDataType.SP1E.rawValue:
            let result = Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
            return result / 16384

        case SMCDataType.SP3C.rawValue:
            let result = Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
            return result / 4096

        case SMCDataType.SP4B.rawValue:
            let result = Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
            return result / 2048

        case SMCDataType.SP5A.rawValue:
            let result = Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
            return result / 1024

        case SMCDataType.SP69.rawValue:
            let result = Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
            return result / 512

        case SMCDataType.SP78.rawValue:
            let intValue = Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
            return intValue / 256

        case SMCDataType.SP87.rawValue:
            let intValue = Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
            return intValue / 128

        case SMCDataType.SP96.rawValue:
            let intValue = Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
            return intValue / 64

        case SMCDataType.SPA5.rawValue:
            let result = Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
            return result / 32

        case SMCDataType.SPB4.rawValue:
            let intValue = Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
            return intValue / 16

        case SMCDataType.SPF0.rawValue:
            let intValue = Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
            return intValue

        case SMCDataType.FLT.rawValue:
            return value.bytes.prefix(4).withUnsafeBytes { ptr in
                return ptr.load(as: Float.self).isNaN ? nil : Double(ptr.load(as: Float.self))
            }

        case SMCDataType.FPE2.rawValue:
            return Double((Int(value.bytes[0]) << 6) | (Int(value.bytes[1]) >> 2))

        default:
            return nil
        }
    }
}

// MARK: - FourCharCode Extensions

private extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4, "FourCharCode requires exactly 4 characters")
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }

    func fourCharCodeToString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8 & 0xff)!) +
               String(describing: UnicodeScalar(self & 0xff)!)
    }
}
