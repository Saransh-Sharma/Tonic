import XCTest
@testable import Tonic

final class WidgetDataManagerLiveMonitoringTests: XCTestCase {
    nonisolated override func tearDown() {
        MainActor.assumeIsolated {
            WidgetDataManager.shared.stopMonitoring()
        }
        super.tearDown()
    }

    @MainActor func testEnsureLiveMonitoringStartsWhenStopped() {
        let manager = WidgetDataManager.shared
        manager.stopMonitoring()

        manager.ensureLiveMonitoring(reason: "test start")

        XCTAssertTrue(manager.isMonitoring)
        XCTAssertTrue(manager.activeReaderIDsForTesting.isSuperset(of: ["CPU.load", "RAM.load", "Disk.load", "Net.load"]))
    }

    @MainActor func testEnsureLiveMonitoringRestartsMissingRequiredReaders() {
        let manager = WidgetDataManager.shared
        manager.stopMonitoring()
        manager.startMonitoring()
        manager.cancelReaderTimersForTesting(keepMonitoring: true)

        XCTAssertTrue(manager.isMonitoring)
        XCTAssertTrue(manager.activeReaderIDsForTesting.isEmpty)

        manager.ensureLiveMonitoring(reason: "test repair missing timers")

        XCTAssertTrue(manager.activeReaderIDsForTesting.isSuperset(of: ["CPU.load", "RAM.load", "Disk.load", "Net.load"]))
    }

    @MainActor func testFirstLiveMetricSampleSetsHealthFields() {
        let manager = WidgetDataManager.shared
        manager.setLastLiveSampleAtForTesting(nil)

        manager.markLiveMetricSampleReceivedForTesting()

        XCTAssertTrue(manager.hasLiveMetricSample)
        XCTAssertNotNil(manager.lastLiveSampleAt)
    }

    @MainActor func testStaleLiveSampleTriggersReaderRepair() {
        let manager = WidgetDataManager.shared
        manager.stopMonitoring()
        manager.startMonitoring()
        manager.setLastLiveSampleAtForTesting(Date().addingTimeInterval(-120))
        manager.cancelReaderTimersForTesting(keepMonitoring: true)

        manager.ensureLiveMonitoring(reason: "test stale repair")

        XCTAssertTrue(manager.isMonitoring)
        XCTAssertTrue(manager.activeReaderIDsForTesting.isSuperset(of: ["CPU.load", "RAM.load", "Disk.load", "Net.load"]))
    }

    @MainActor func testNetworkLiveSamplingDoesNotBlockOnSynchronousPing() throws {
        let source = try widgetDataManagerSource()
        guard let cpuRange = source.range(of: "private func updateCPUData()"),
              let cpuEndRange = source.range(of: "private func getCPUUsageSnapshot()"),
              let memoryRange = source.range(of: "private func updateMemoryData()"),
              let memoryEndRange = source.range(of: "// MARK: - Enhanced Memory Readers"),
              let diskRange = source.range(of: "private func updateDiskData()"),
              let diskEndRange = source.range(of: "// MARK: - Enhanced Disk Readers"),
              let updateRange = source.range(of: "private func updateNetworkData()"),
              let statsRange = source.range(of: "private func getNetworkStats()"),
              let loadAverageRange = source.range(of: "private func getAverageLoad()"),
              let uptimeRange = source.range(of: "private func getSystemUptime()") else {
            XCTFail("Expected WidgetDataManager live sampling functions to exist")
            return
        }

        let cpuSource = String(source[cpuRange.lowerBound..<cpuEndRange.lowerBound])
        XCTAssertFalse(cpuSource.contains("getCachedThermalLimit()"))
        XCTAssertFalse(cpuSource.contains("getCachedCPUSpeedLimits()"))

        let memorySource = String(source[memoryRange.lowerBound..<memoryEndRange.lowerBound])
        XCTAssertFalse(memorySource.contains("getTopMemoryProcesses()"))

        let diskSource = String(source[diskRange.lowerBound..<diskEndRange.lowerBound])
        XCTAssertFalse(diskSource.contains("getNVMeSMARTData()"))
        XCTAssertFalse(diskSource.contains("getTopDiskProcesses()"))

        let updateNetworkSource = String(source[updateRange.lowerBound..<statsRange.lowerBound])
        XCTAssertFalse(updateNetworkSource.contains("performPingTest"))
        XCTAssertFalse(updateNetworkSource.contains("getTopNetworkProcesses()"))
        XCTAssertFalse(updateNetworkSource.contains("getConnectionType()"))
        XCTAssertFalse(updateNetworkSource.contains("getWiFiSSID()"))
        XCTAssertFalse(updateNetworkSource.contains("getWiFiDetails()"))
        XCTAssertFalse(updateNetworkSource.contains("getPrimaryInterfaceName()"))
        XCTAssertFalse(updateNetworkSource.contains("getLinkSpeedMbps"))
        XCTAssertFalse(source.contains("if_indextoname"))
        XCTAssertFalse(source.contains("if_nametoindex"))
        XCTAssertTrue(source.contains("scheduleConnectivityRefreshIfNeeded"))
        XCTAssertTrue(source.contains("MonitoringReader(id: \"GPU.load\", module: .gpu, intervalKey: \"GPU_updateInterval\", defaultInterval: 1.0, popupOnly: true)"))
        XCTAssertTrue(source.contains("MonitoringReader(id: \"Battery.load\", module: .battery, intervalKey: \"Battery_updateInterval\", defaultInterval: 2.0, popupOnly: true)"))
        XCTAssertTrue(source.contains("MonitoringReader(id: \"Sensors.load\", module: .sensors, intervalKey: \"Sensors_updateInterval\", defaultInterval: 2.0, popupOnly: true)"))
        XCTAssertTrue(source.contains("MonitoringReader(id: \"Bluetooth.load\", module: .bluetooth, intervalKey: \"Bluetooth_updateInterval\", defaultInterval: bluetoothUpdateInterval, popupOnly: true)"))
        XCTAssertTrue(source.contains("UserDefaults.standard.bool(forKey: \"WidgetDataManagerDebugLogging\")"))

        let loadAverageSource = String(source[loadAverageRange.lowerBound..<uptimeRange.lowerBound])
        XCTAssertFalse(loadAverageSource.contains("Process()"))
        XCTAssertFalse(loadAverageSource.contains("waitUntilExit()"))
        XCTAssertTrue(loadAverageSource.contains("getloadavg"))

        guard let pingRange = source.range(of: "func performPingTest"),
              let jitterRange = source.range(of: "func calculateJitter") else {
            XCTFail("Expected ping helper and jitter helper to exist")
            return
        }
        let pingSource = String(source[pingRange.lowerBound..<jitterRange.lowerBound])
        XCTAssertFalse(pingSource.contains("task.waitUntilExit()"))
        XCTAssertTrue(pingSource.contains("task.terminate()"))
    }

    private func widgetDataManagerSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent("Tonic/Tonic/Services/WidgetDataManager.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
