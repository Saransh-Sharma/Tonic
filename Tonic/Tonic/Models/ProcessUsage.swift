//
//  ProcessUsage.swift
//  Tonic
//
//  Per-process resource usage data model
//  Task ID: fn-6-i4g.2
//

import Foundation
import AppKit

/// Per-process resource usage information
/// Used for process monitoring UI and detailed stats
public struct ProcessUsage: Identifiable, Sendable {
    public let id: Int32  // PID
    public let name: String
    public let iconData: Data?  // Raw icon data (NSImage is not Sendable)
    public let cpuUsage: Double?
    public let memoryUsage: UInt64?
    public let diskReadBytes: UInt64?
    public let diskWriteBytes: UInt64?
    public let networkBytes: UInt64?

    public init(
        id: Int32,
        name: String,
        iconData: Data? = nil,
        cpuUsage: Double? = nil,
        memoryUsage: UInt64? = nil,
        diskReadBytes: UInt64? = nil,
        diskWriteBytes: UInt64? = nil,
        networkBytes: UInt64? = nil
    ) {
        self.id = id
        self.name = name
        self.iconData = iconData
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskReadBytes = diskReadBytes
        self.diskWriteBytes = diskWriteBytes
        self.networkBytes = networkBytes
    }

    /// Recover NSImage from stored data (convenience for UI)
    public func icon() -> NSImage? {
        guard let iconData = iconData else { return nil }
        return NSImage(data: iconData)
    }

    /// Create ProcessUsage with NSImage (stores it as Data)
    public func withIcon(_ image: NSImage?) -> ProcessUsage {
        var data: Data?
        if let image = image, let tiffData = image.tiffRepresentation {
            data = tiffData
        }
        return ProcessUsage(
            id: self.id,
            name: self.name,
            iconData: data,
            cpuUsage: self.cpuUsage,
            memoryUsage: self.memoryUsage,
            diskReadBytes: self.diskReadBytes,
            diskWriteBytes: self.diskWriteBytes,
            networkBytes: self.networkBytes
        )
    }

    /// Memory usage formatted as string
    public var memoryUsageString: String? {
        guard let memoryUsage = memoryUsage else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }

    /// Disk read formatted as string
    public var diskReadString: String? {
        guard let diskReadBytes = diskReadBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(diskReadBytes), countStyle: .binary)
    }

    /// Disk write formatted as string
    public var diskWriteString: String? {
        guard let diskWriteBytes = diskWriteBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(diskWriteBytes), countStyle: .binary)
    }
}

// MARK: - Codable Support

/// Codable version of ProcessUsage (without icon)
public struct ProcessUsageSummary: Identifiable, Sendable, Codable, Equatable {
    public let id: Int32
    public let name: String
    public let cpuUsage: Double?
    public let memoryUsage: UInt64?
    public let diskReadBytes: UInt64?
    public let diskWriteBytes: UInt64?
    public let networkBytes: UInt64?

    public init(
        id: Int32,
        name: String,
        cpuUsage: Double? = nil,
        memoryUsage: UInt64? = nil,
        diskReadBytes: UInt64? = nil,
        diskWriteBytes: UInt64? = nil,
        networkBytes: UInt64? = nil
    ) {
        self.id = id
        self.name = name
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskReadBytes = diskReadBytes
        self.diskWriteBytes = diskWriteBytes
        self.networkBytes = networkBytes
    }

    /// Create from ProcessUsage
    public init(from process: ProcessUsage) {
        self.id = process.id
        self.name = process.name
        self.cpuUsage = process.cpuUsage
        self.memoryUsage = process.memoryUsage
        self.diskReadBytes = process.diskReadBytes
        self.diskWriteBytes = process.diskWriteBytes
        self.networkBytes = process.networkBytes
    }
}
