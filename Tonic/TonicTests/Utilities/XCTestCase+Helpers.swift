//
//  XCTestCase+Helpers.swift
//  TonicTests
//
//  Helper extensions for XCTest assertions and utilities
//

import XCTest
import SwiftUI

/// Common test assertions and helpers
extension XCTestCase {
    /// Assert that a closure does not throw an error
    func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        do {
            _ = try expression()
        } catch {
            XCTFail("Expected no error, but got: \(error)" + (message().isEmpty ? "" : " - \(message())"), file: file, line: line)
        }
    }

    /// Assert that two floating point values are approximately equal
    func XCTAssertApproximatelyEqual(
        _ expression1: @autoclosure () -> Double,
        _ expression2: @autoclosure () -> Double,
        accuracy: Double = 0.01,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let val1 = expression1()
        let val2 = expression2()
        let difference = abs(val1 - val2)

        if difference > accuracy {
            XCTFail("Expected \(val1) to be approximately equal to \(val2) (accuracy: \(accuracy), difference: \(difference))" + (message().isEmpty ? "" : " - \(message())"), file: file, line: line)
        }
    }

    /// Assert color contrast ratio
    func XCTAssertColorContrast(
        foreground: NSColor,
        background: NSColor,
        minimumRatio: Double = 4.5,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ratio = ColorAccessibilityHelper.contrastRatio(foreground: foreground, background: background)
        XCTAssertGreaterThanOrEqual(
            ratio,
            minimumRatio,
            "Color contrast ratio \(String(format: "%.2f", ratio)) is below minimum \(String(format: "%.2f", minimumRatio))" + (message().isEmpty ? "" : " - \(message())"),
            file: file,
            line: line
        )
    }

    /// Measure execution time of a closure
    func measureExecutionTime(_ block: @escaping () -> Void) -> TimeInterval {
        let start = Date()
        block()
        return Date().timeIntervalSince(start)
    }

    /// Wait for a condition to be true with timeout
    func waitForCondition(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 1.0,
        message: String = "Condition not met within timeout"
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), message)
    }
}
