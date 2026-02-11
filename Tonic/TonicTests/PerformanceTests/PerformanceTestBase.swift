//
//  PerformanceTestBase.swift
//  TonicTests
//
//  Base class and utilities for performance testing
//

import XCTest
import Foundation

/// Base class for performance tests with measurement utilities
class PerformanceTestBase: XCTestCase {

    // MARK: - Performance Metrics

    /// Stores performance measurement results
    struct PerformanceResult {
        let testName: String
        let duration: TimeInterval
        let memoryUsed: Int64?
        let cpuUsage: Double?
        let date: Date
        let passed: Bool
        let target: TimeInterval?
    }

    static var performanceResults: [PerformanceResult] = []

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        // Clear any state before test
        setUpTest()
    }

    override func tearDown() {
        tearDownTest()
        super.tearDown()
    }

    /// Override to add custom setup
    func setUpTest() {
        // Default implementation does nothing
    }

    /// Override to add custom teardown
    func tearDownTest() {
        // Default implementation does nothing
    }

    // MARK: - Timing Utilities

    /// Measure execution time of a closure
    func measureExecutionTime(
        iterations: Int = 1,
        closure: () -> Void
    ) -> TimeInterval {
        let start = Date()
        for _ in 0..<iterations {
            closure()
        }
        return Date().timeIntervalSince(start)
    }

    /// Measure execution time of an async closure
    @available(macOS 10.15, *)
    func measureAsyncExecutionTime(
        iterations: Int = 1,
        closure: () async -> Void
    ) async -> TimeInterval {
        let start = Date()
        for _ in 0..<iterations {
            await closure()
        }
        return Date().timeIntervalSince(start)
    }

    /// Measure execution time with target threshold
    func measureWithTarget(
        target: TimeInterval,
        label: String,
        iterations: Int = 1,
        closure: () -> Void
    ) {
        let duration = measureExecutionTime(iterations: iterations, closure: closure)
        let average = duration / Double(iterations)

        let passed = average <= target
        let status = passed ? "✅ PASS" : "❌ FAIL"

        print("\(label): \(String(format: "%.3f", average))s (target: \(String(format: "%.3f", target))s) \(status)")

        XCTAssertLessThanOrEqual(
            average,
            target,
            "\(label) exceeded target threshold. Expected: \(target)s, Got: \(average)s"
        )
    }

    // MARK: - Memory Utilities

    /// Get current memory usage in bytes
    func getMemoryUsage() -> Int64 {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size)
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        return 0
    }

    /// Measure memory used by a closure
    func measureMemoryUsage(closure: () -> Void) -> Int64 {
        // Drain autorelease pools without synchronously re-entering main queue.
        let drainAutoreleasePool = {
            autoreleasepool {
                // Clear autorelease pool
            }
        }
        if Thread.isMainThread {
            drainAutoreleasePool()
        } else {
            DispatchQueue.main.sync(execute: drainAutoreleasePool)
        }

        let beforeMemory = getMemoryUsage()
        closure()
        let afterMemory = getMemoryUsage()

        return max(0, afterMemory - beforeMemory)
    }

    /// Assert memory usage is below threshold
    func XCTAssertMemoryUsageBelow(
        _ threshold: Int64,
        closure: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let used = measureMemoryUsage(closure: closure)
        XCTAssertLessThanOrEqual(
            used,
            threshold,
            "Memory usage \(ByteCountFormatter.string(fromByteCount: used, countStyle: .file)) exceeded threshold \(ByteCountFormatter.string(fromByteCount: threshold, countStyle: .file))",
            file: file,
            line: line
        )
    }

    // MARK: - Performance Assertions

    /// Assert execution time is below threshold
    func XCTAssertPerformance(
        _ closure: () -> Void,
        isLessThan threshold: TimeInterval,
        iterations: Int = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let duration = measureExecutionTime(iterations: iterations, closure: closure)
        let average = duration / Double(iterations)

        XCTAssertLessThanOrEqual(
            average,
            threshold,
            "Performance test exceeded threshold. Expected: \(threshold)s, Got: \(average)s",
            file: file,
            line: line
        )
    }

    /// Assert operation completes within specified time
    func XCTAssertCompletes(
        within timeout: TimeInterval,
        operation: @escaping () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "Operation completes within timeout")
        let deadline = Date().addingTimeInterval(timeout)

        DispatchQueue.global().async {
            operation()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout + 0.1)

        if Date() > deadline {
            XCTFail("Operation did not complete within \(timeout)s", file: file, line: line)
        }
    }

    // MARK: - Benchmark Reporting

    /// Record a performance result
    static func recordResult(
        testName: String,
        duration: TimeInterval,
        target: TimeInterval? = nil,
        memoryUsed: Int64? = nil,
        cpuUsage: Double? = nil
    ) {
        let passed = target == nil || duration <= target!
        let result = PerformanceResult(
            testName: testName,
            duration: duration,
            memoryUsed: memoryUsed,
            cpuUsage: cpuUsage,
            date: Date(),
            passed: passed,
            target: target
        )
        performanceResults.append(result)
    }

    /// Generate performance report
    static func generatePerformanceReport() -> String {
        var report = "\n=== Performance Test Results ===\n"
        report += String(format: "Total Tests: %d\n", performanceResults.count)

        let passed = performanceResults.filter { $0.passed }.count
        let failed = performanceResults.filter { !$0.passed }.count
        report += String(format: "Passed: %d, Failed: %d\n\n", passed, failed)

        for result in performanceResults {
            let status = result.passed ? "✅" : "❌"
            report += "\(status) \(result.testName)\n"
            report += "   Duration: \(String(format: "%.3f", result.duration))s"
            if let target = result.target {
                report += " (target: \(String(format: "%.3f", target))s)"
            }
            report += "\n"

            if let memory = result.memoryUsed {
                report += "   Memory: \(ByteCountFormatter.string(fromByteCount: memory, countStyle: .file))\n"
            }
        }

        return report
    }
}

// MARK: - Task Info Import

#if os(macOS)
    import Darwin

    private let TASK_BASIC_INFO = task_flavor_t(1)
#endif
