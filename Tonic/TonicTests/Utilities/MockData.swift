//
//  MockData.swift
//  TonicTests
//
//  Provides test data and mock objects for unit tests
//

import Foundation

/// Factory for creating mock test data
struct MockData {
    /// Create a mock health score for testing
    static func mockHealthScore(value: Int = 75) -> Int {
        return min(max(value, 0), 100)
    }

    /// Create mock system metrics
    static func mockSystemMetrics() -> (cpu: Double, memory: Double, disk: Double) {
        return (cpu: 45.5, memory: 62.3, disk: 58.2)
    }

    /// Create a mock file path for testing
    static func mockFilePath() -> String {
        return "/Users/test/Documents/test.txt"
    }

    /// Create mock file list
    static func mockFileList(count: Int = 10) -> [String] {
        return (0..<count).map { "file_\($0).txt" }
    }

    /// Create a mock app item
    static func mockAppItem(name: String = "TestApp", size: Int = 1000) -> (name: String, path: String, size: Int) {
        return (name: name, path: "/Applications/\(name).app", size: size)
    }
}

/// Mock notification center for testing
class MockNotificationCenter {
    var notifications: [(name: NSNotification.Name, object: Any?)] = []

    func post(name: NSNotification.Name, object: Any? = nil) {
        notifications.append((name, object))
    }

    func clear() {
        notifications.removeAll()
    }

    func hasNotification(name: NSNotification.Name) -> Bool {
        return notifications.contains { $0.name == name }
    }
}
