//
//  BluetoothReader.swift
//  Tonic
//
//  Bluetooth device reader conforming to WidgetReader protocol
//  Uses IOBluetooth framework to read paired device info without permission dialogs
//  Task ID: fn-6-i4g.15
//

import Foundation
import IOKit
import IOBluetooth
import AppKit

// MARK: - Bluetooth Data Models

/// Type of Bluetooth device
public enum BluetoothDeviceType: String, Sendable, Codable {
    case keyboard = "keyboard"
    case mouse = "mouse"
    case trackpad = "trackpad"
    case headphones = "headphones"
    case speaker = "speaker"
    case airpods = "airpods"
    case controller = "controller"
    case other = "other"

    /// SF Symbol for this device type
    public var icon: String {
        switch self {
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .headphones: return "headphones"
        case .speaker: return "hifispeaker"
        case .airpods: return "airpodspro"
        case .controller: return "gamecontroller"
        case .other: return "wave.3.right"
        }
    }

    public var displayName: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .mouse: return "Mouse"
        case .trackpad: return "Trackpad"
        case .headphones: return "Headphones"
        case .speaker: return "Speaker"
        case .airpods: return "AirPods"
        case .controller: return "Controller"
        case .other: return "Device"
        }
    }
}

/// Battery level component for devices with multiple batteries (e.g., AirPods)
public struct BluetoothBatteryLevel: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public let label: String  // "Main", "Left", "Right", "Case"
    public let percentage: Int  // 0-100

    public init(id: String = UUID().uuidString, label: String, percentage: Int) {
        self.id = id
        self.label = label
        self.percentage = max(0, min(100, percentage))
    }
}

/// Bluetooth device information
public struct BluetoothDevice: Sendable, Codable, Identifiable, Equatable {
    public let id: String  // UUID or address
    public let name: String
    public let address: String
    public let deviceType: BluetoothDeviceType
    public let isConnected: Bool
    public let isPaired: Bool
    public let batteryLevels: [BluetoothBatteryLevel]  // Multiple for AirPods
    public let rssi: Int?  // Signal strength in dBm

    public init(
        id: String,
        name: String,
        address: String,
        deviceType: BluetoothDeviceType,
        isConnected: Bool,
        isPaired: Bool,
        batteryLevels: [BluetoothBatteryLevel],
        rssi: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.deviceType = deviceType
        self.isConnected = isConnected
        self.isPaired = isPaired
        self.batteryLevels = batteryLevels
        self.rssi = rssi
    }

    /// Primary battery level (first or main battery)
    public var primaryBatteryLevel: Int? {
        batteryLevels.first?.percentage
    }

    /// Whether this device has battery information
    public var hasBattery: Bool {
        !batteryLevels.isEmpty
    }
}

/// Bluetooth module data
public struct BluetoothData: Sendable, Equatable {
    public let isBluetoothEnabled: Bool
    public let devices: [BluetoothDevice]
    public let timestamp: Date

    public init(
        isBluetoothEnabled: Bool = true,
        devices: [BluetoothDevice] = [],
        timestamp: Date = Date()
    ) {
        self.isBluetoothEnabled = isBluetoothEnabled
        self.devices = devices
        self.timestamp = timestamp
    }

    /// Connected devices only
    public var connectedDevices: [BluetoothDevice] {
        devices.filter { $0.isConnected }
    }

    /// Devices with battery info
    public var devicesWithBattery: [BluetoothDevice] {
        devices.filter { $0.hasBattery }
    }

    /// Empty data (no Bluetooth or no devices)
    public static let empty = BluetoothData(isBluetoothEnabled: false, devices: [])
}

// MARK: - Bluetooth Reader

/// Bluetooth data reader conforming to WidgetReader protocol
/// Reads device information via IOBluetooth and HID services
@MainActor
final class BluetoothReader: WidgetReader {
    typealias Output = BluetoothData

    let preferredInterval: TimeInterval = 10.0  // Bluetooth status doesn't change frequently

    init() {}

    func read() async throws -> BluetoothData {
        // Run on background thread for IOKit calls
        return await Task.detached {
            self.getBluetoothData()
        }.value
    }

    private func getBluetoothData() -> BluetoothData {
        var devices: [BluetoothDevice] = []

        // Check if Bluetooth is powered on
        let isEnabled = isBluetoothPoweredOn()

        guard isEnabled else {
            return BluetoothData(isBluetoothEnabled: false, devices: [])
        }

        // Get HID devices (keyboard, mouse, trackpad) with battery levels
        let hidDevices = getHIDDevices()
        devices.append(contentsOf: hidDevices)

        // Get paired/connected devices from IOBluetooth
        let ioDevices = getIOBluetoothDevices()

        // Merge IO devices that aren't already in HID list
        for ioDevice in ioDevices {
            if !devices.contains(where: { $0.address.lowercased() == ioDevice.address.lowercased() }) {
                devices.append(ioDevice)
            }
        }

        // Get device cache for battery levels (AirPods, etc.)
        let cacheDevices = getDeviceCacheBatteryLevels()

        // Merge cache battery data into existing devices
        for cacheDevice in cacheDevices {
            if let index = devices.firstIndex(where: { $0.address.lowercased() == cacheDevice.address.lowercased() }) {
                // Update with battery info if we didn't have it
                if devices[index].batteryLevels.isEmpty && !cacheDevice.batteryLevels.isEmpty {
                    let updated = BluetoothDevice(
                        id: devices[index].id,
                        name: devices[index].name,
                        address: devices[index].address,
                        deviceType: devices[index].deviceType,
                        isConnected: devices[index].isConnected,
                        isPaired: devices[index].isPaired,
                        batteryLevels: cacheDevice.batteryLevels,
                        rssi: devices[index].rssi
                    )
                    devices[index] = updated
                }
            } else if !cacheDevice.batteryLevels.isEmpty {
                // Add device from cache if it has battery info
                devices.append(cacheDevice)
            }
        }

        return BluetoothData(
            isBluetoothEnabled: true,
            devices: devices,
            timestamp: Date()
        )
    }

    // MARK: - Bluetooth Power State

    private func isBluetoothPoweredOn() -> Bool {
        // Check Bluetooth power state via IORegistry
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOBluetoothHCIController"),
            &iterator
        )

        guard result == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        // Try to get power state
        if let powerState = IORegistryEntryCreateCFProperty(
            service,
            "HCIControllerPowerIsOn" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool {
            return powerState
        }

        // Fallback: assume enabled if we can enumerate devices
        return IOBluetoothDevice.pairedDevices() != nil
    }

    // MARK: - HID Devices (Keyboard, Mouse, Trackpad)

    private func getHIDDevices() -> [BluetoothDevice] {
        var devices: [BluetoothDevice] = []

        guard let ioDevices = fetchIOService("AppleDeviceManagementHIDEventService") else {
            return []
        }

        for dict in ioDevices {
            // Only process Bluetooth devices
            guard let isBluetoothDevice = dict["BluetoothDevice"] as? Bool,
                  isBluetoothDevice,
                  let name = dict["Product"] as? String else {
                continue
            }

            // Get address (try multiple keys)
            var address: String = ""
            if let addr = dict["DeviceAddress"] as? String, !addr.isEmpty {
                address = addr
            } else if let addr = dict["SerialNumber"] as? String, !addr.isEmpty {
                address = addr
            } else if let bleAddr = dict["BD_ADDR"] as? Data,
                      let addr = String(data: bleAddr, encoding: .utf8), !addr.isEmpty {
                address = addr
            }

            guard !address.isEmpty else { continue }

            // Get battery level
            var batteryLevels: [BluetoothBatteryLevel] = []
            if let batteryPercent = dict["BatteryPercent"] as? Int {
                batteryLevels.append(BluetoothBatteryLevel(label: "Battery", percentage: batteryPercent))
            }

            // Determine device type from name or product info
            let deviceType = inferDeviceType(from: name, dict: dict)

            devices.append(BluetoothDevice(
                id: address,
                name: name,
                address: address,
                deviceType: deviceType,
                isConnected: true,  // HID devices are connected if they appear here
                isPaired: true,
                batteryLevels: batteryLevels,
                rssi: nil
            ))
        }

        return devices
    }

    // MARK: - IOBluetooth Paired Devices

    private func getIOBluetoothDevices() -> [BluetoothDevice] {
        var devices: [BluetoothDevice] = []

        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        for device in pairedDevices {
            guard device.isPaired() || device.isConnected() else { continue }

            let address = device.addressString ?? ""
            guard !address.isEmpty else { continue }

            let name = device.nameOrAddress ?? "Unknown Device"
            let rssi = device.rssi()
            let rssiValue: Int? = rssi == 127 ? nil : Int(rssi)

            // Determine device type from name and device class
            let deviceType = inferDeviceType(from: name, deviceClass: device.classOfDevice)

            devices.append(BluetoothDevice(
                id: address,
                name: name,
                address: normalizeAddress(address),
                deviceType: deviceType,
                isConnected: device.isConnected(),
                isPaired: device.isPaired(),
                batteryLevels: [],  // Battery comes from cache or HID
                rssi: rssiValue
            ))
        }

        return devices
    }

    // MARK: - Device Cache (AirPods battery levels)

    private func getDeviceCacheBatteryLevels() -> [BluetoothDevice] {
        var devices: [BluetoothDevice] = []

        guard let cache = UserDefaults(suiteName: "/Library/Preferences/com.apple.Bluetooth"),
              let deviceCache = cache.object(forKey: "DeviceCache") as? [String: [String: Any]],
              let pairedDevices = cache.object(forKey: "PairedDevices") as? [String] else {
            return []
        }

        for (address, dict) in deviceCache where pairedDevices.contains(address) {
            let name = dict["Name"] as? String ?? "Unknown Device"
            var batteryLevels: [BluetoothBatteryLevel] = []

            // Check for various battery keys (AirPods have multiple)
            let batteryKeys: [(key: String, label: String)] = [
                ("BatteryPercent", "Battery"),
                ("BatteryPercentCase", "Case"),
                ("BatteryPercentLeft", "Left"),
                ("BatteryPercentRight", "Right")
            ]

            for (key, label) in batteryKeys {
                if let value = dict[key] {
                    var percentage: Int = 0
                    switch value {
                    case let intValue as Int:
                        percentage = intValue
                        if percentage == 1 {
                            percentage = 100  // Some APIs report 1 for 100%
                        }
                    case let doubleValue as Double:
                        percentage = Int(doubleValue * 100)
                    default:
                        continue
                    }

                    if percentage > 0 {
                        batteryLevels.append(BluetoothBatteryLevel(label: label, percentage: percentage))
                    }
                }
            }

            let deviceType = inferDeviceType(from: name, dict: dict)

            devices.append(BluetoothDevice(
                id: address,
                name: name,
                address: normalizeAddress(address),
                deviceType: deviceType,
                isConnected: false,  // We don't know from cache
                isPaired: true,
                batteryLevels: batteryLevels,
                rssi: nil
            ))
        }

        return devices
    }

    // MARK: - Helper Methods

    private func fetchIOService(_ serviceName: String) -> [[String: Any]]? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(serviceName),
            &iterator
        )

        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var devices: [[String: Any]] = []

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            var properties: Unmanaged<CFMutableDictionary>?
            let propResult = IORegistryEntryCreateCFProperties(
                service,
                &properties,
                kCFAllocatorDefault,
                0
            )

            if propResult == KERN_SUCCESS, let props = properties?.takeRetainedValue() as? [String: Any] {
                devices.append(props)
            }
        }

        return devices.isEmpty ? nil : devices
    }

    private func inferDeviceType(from name: String, dict: [String: Any]? = nil, deviceClass: BluetoothClassOfDevice = 0) -> BluetoothDeviceType {
        let lowercaseName = name.lowercased()

        // Check name patterns
        if lowercaseName.contains("keyboard") {
            return .keyboard
        } else if lowercaseName.contains("mouse") || lowercaseName.contains("magic mouse") {
            return .mouse
        } else if lowercaseName.contains("trackpad") {
            return .trackpad
        } else if lowercaseName.contains("airpods") {
            return .airpods
        } else if lowercaseName.contains("headphone") || lowercaseName.contains("beats") ||
                    lowercaseName.contains("buds") || lowercaseName.contains("earphone") {
            return .headphones
        } else if lowercaseName.contains("speaker") || lowercaseName.contains("homepod") {
            return .speaker
        } else if lowercaseName.contains("controller") || lowercaseName.contains("gamepad") ||
                    lowercaseName.contains("dualshock") || lowercaseName.contains("xbox") {
            return .controller
        }

        // Check device class if available
        // Major class is bits 8-12
        let majorClass = (deviceClass >> 8) & 0x1F
        switch majorClass {
        case 5:  // Peripheral
            let minorClass = (deviceClass >> 2) & 0x3F
            if minorClass & 0x10 != 0 { return .keyboard }
            if minorClass & 0x20 != 0 { return .mouse }
            if minorClass & 0x01 != 0 { return .controller }
        case 4:  // Audio/Video
            return .headphones
        default:
            break
        }

        return .other
    }

    private func normalizeAddress(_ address: String) -> String {
        address.replacingOccurrences(of: ":", with: "-").lowercased()
    }
}
