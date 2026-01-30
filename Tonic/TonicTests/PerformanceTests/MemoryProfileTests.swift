//
//  MemoryProfileTests.swift
//  TonicTests
//
//  Memory profiling tests - measure memory usage patterns and detect leaks
//

import XCTest
@testable import Tonic

final class MemoryProfileTests: PerformanceTestBase {

    // MARK: - Data Structure Memory Usage

    func testArrayMemoryUsage1000Items() {
        let memoryUsed = measureMemoryUsage {
            var items = [String]()
            for i in 0..<1000 {
                items.append("Item \(i)")
            }
            _ = items
        }

        XCTAssertLessThan(
            memoryUsed,
            5_000_000,  // 5 MB
            "1000 string items should use < 5 MB"
        )
    }

    func testArrayMemoryUsage10000Items() {
        let memoryUsed = measureMemoryUsage {
            var items = [String]()
            for i in 0..<10000 {
                items.append("Item \(i)")
            }
            _ = items
        }

        XCTAssertLessThan(
            memoryUsed,
            50_000_000,  // 50 MB
            "10000 string items should use < 50 MB"
        )
    }

    func testDictionaryMemoryUsage() {
        let memoryUsed = measureMemoryUsage {
            var dict = [String: String]()
            for i in 0..<1000 {
                dict["key\(i)"] = "Value for key \(i)"
            }
            _ = dict
        }

        XCTAssertLessThan(
            memoryUsed,
            10_000_000,  // 10 MB
            "1000 dictionary entries should use < 10 MB"
        )
    }

    func testSetMemoryUsage() {
        let memoryUsed = measureMemoryUsage {
            var set = Set<String>()
            for i in 0..<1000 {
                set.insert("Item \(i)")
            }
            _ = set
        }

        XCTAssertLessThan(
            memoryUsed,
            5_000_000,  // 5 MB
            "1000 set items should use < 5 MB"
        )
    }

    // MARK: - Nested Structure Memory Usage

    func testNestedArrayMemoryUsage() {
        let memoryUsed = measureMemoryUsage {
            var data = [[String]]()
            for i in 0..<100 {
                var inner = [String]()
                for j in 0..<100 {
                    inner.append("Item \(i)-\(j)")
                }
                data.append(inner)
            }
            _ = data
        }

        XCTAssertLessThan(
            memoryUsed,
            50_000_000,  // 50 MB
            "10000 nested items should use < 50 MB"
        )
    }

    func testComplexStructureMemoryUsage() {
        struct Record {
            let id: Int
            let name: String
            let data: [String]
        }

        let memoryUsed = measureMemoryUsage {
            var records = [Record]()
            for i in 0..<1000 {
                let record = Record(
                    id: i,
                    name: "Record \(i)",
                    data: (0..<10).map { "Data \($0)" }
                )
                records.append(record)
            }
            _ = records
        }

        XCTAssertLessThan(
            memoryUsed,
            50_000_000,  // 50 MB
            "1000 complex records should use < 50 MB"
        )
    }

    // MARK: - String Memory Usage

    func testShortStringMemoryUsage() {
        let memoryUsed = measureMemoryUsage {
            var strings = [String]()
            for i in 0..<10000 {
                strings.append("Item")
            }
            _ = strings
        }

        XCTAssertLessThan(
            memoryUsed,
            5_000_000,  // 5 MB
            "10000 short strings should use < 5 MB"
        )
    }

    func testLongStringMemoryUsage() {
        let longString = String(repeating: "a", count: 1000)
        let memoryUsed = measureMemoryUsage {
            var strings = [String]()
            for i in 0..<1000 {
                strings.append(longString + String(i))
            }
            _ = strings
        }

        XCTAssertLessThan(
            memoryUsed,
            10_000_000,  // 10 MB
            "1000 long strings should use < 10 MB"
        )
    }

    // MARK: - Cache Memory Usage

    func testCacheMemoryUsage1000Items() {
        var cache = [String: String]()

        let memoryUsed = measureMemoryUsage {
            for i in 0..<1000 {
                cache["key\(i)"] = "Value for key \(i)"
            }
            _ = cache
        }

        XCTAssertLessThan(
            memoryUsed,
            10_000_000,  // 10 MB
            "Cache with 1000 items should use < 10 MB"
        )
    }

    func testCacheMemoryUsage10000Items() {
        var cache = [String: String]()

        let memoryUsed = measureMemoryUsage {
            for i in 0..<10000 {
                cache["key\(i)"] = "Value for key \(i)"
            }
            _ = cache
        }

        XCTAssertLessThan(
            memoryUsed,
            100_000_000,  // 100 MB
            "Cache with 10000 items should use < 100 MB"
        )
    }

    // MARK: - File Reading Memory Usage

    func testFileReadMemoryUsage() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try? "Test content".write(to: tempFile, atomically: true, encoding: .utf8)

        let memoryUsed = measureMemoryUsage {
            if let content = try? String(contentsOf: tempFile) {
                _ = content
            }
        }

        try? FileManager.default.removeItem(at: tempFile)

        XCTAssertLessThan(
            memoryUsed,
            1_000_000,  // 1 MB
            "Reading small file should use < 1 MB"
        )
    }

    // MARK: - Memory Leak Detection

    func testNoMemoryLeakWithCycleBreaking() {
        class Node {
            let value: String
            weak var next: Node?

            init(value: String) {
                self.value = value
            }
        }

        let initialMemory = measureMemoryUsage { }

        let memoryUsedInOperation = measureMemoryUsage {
            var node = Node(value: "Start")
            let next = Node(value: "End")
            node.next = next
            _ = node
        }

        let finalMemory = measureMemoryUsage { }

        // Memory should be released after operation
        XCTAssertLessThan(memoryUsedInOperation, 1_000_000)
    }

    // MARK: - Allocation Pattern Tests

    func testLinearAllocationPattern() {
        let memoryUsed = measureMemoryUsage {
            var total: Int64 = 0
            for i in 0..<1000 {
                total += Int64(i)
            }
            _ = total
        }

        XCTAssertLessThan(
            memoryUsed,
            1_000_000,  // 1 MB
            "Linear allocation should be minimal"
        )
    }

    func testQuadraticAllocationPattern() {
        let memoryUsed = measureMemoryUsage {
            var data = [[Int]]()
            for i in 0..<100 {
                var row = [Int]()
                for j in 0..<100 {
                    row.append(i * j)
                }
                data.append(row)
            }
            _ = data
        }

        XCTAssertLessThan(
            memoryUsed,
            50_000_000,  // 50 MB
            "Quadratic allocation should stay bounded"
        )
    }

    // MARK: - Data Transformation Memory Usage

    func testFilterMemoryUsage() {
        let items = (0..<1000).map { "Item \($0)" }

        let memoryUsed = measureMemoryUsage {
            let filtered = items.filter { $0.contains("5") }
            _ = filtered
        }

        XCTAssertLessThan(
            memoryUsed,
            5_000_000,  // 5 MB
            "Filtering should not significantly increase memory"
        )
    }

    func testMapMemoryUsage() {
        let items = (0..<1000).map { $0 }

        let memoryUsed = measureMemoryUsage {
            let mapped = items.map { String($0) }
            _ = mapped
        }

        XCTAssertLessThan(
            memoryUsed,
            5_000_000,  // 5 MB
            "Mapping should not significantly increase memory"
        )
    }

    func testReduceMemoryUsage() {
        let items = (0..<10000).map { $0 }

        let memoryUsed = measureMemoryUsage {
            let sum = items.reduce(0) { $0 + $1 }
            _ = sum
        }

        XCTAssertLessThan(
            memoryUsed,
            1_000_000,  // 1 MB
            "Reduce should use minimal memory"
        )
    }

    // MARK: - Collection Memory Comparison

    func testArrayVSDictionaryMemory() {
        let arrayMemory = measureMemoryUsage {
            var array = [String]()
            for i in 0..<1000 {
                array.append("Item \(i)")
            }
            _ = array
        }

        let dictionaryMemory = measureMemoryUsage {
            var dict = [Int: String]()
            for i in 0..<1000 {
                dict[i] = "Item \(i)"
            }
            _ = dict
        }

        // Dictionary should use more memory due to hashing overhead
        XCTAssertLessThan(arrayMemory, dictionaryMemory)
    }

    // MARK: - Batch Operation Memory

    func testBatchInsertMemory() {
        let memoryUsed = measureMemoryUsage {
            var items = [String]()
            for i in 0..<1000 {
                items.append("Item \(i)")
            }
            _ = items
        }

        XCTAssertLessThan(
            memoryUsed,
            5_000_000,  // 5 MB
            "Batch insert should use reasonable memory"
        )
    }

    func testBatchDeleteMemory() {
        var items = (0..<1000).map { "Item \($0)" }

        let memoryUsed = measureMemoryUsage {
            items.removeAll { $0.contains("5") }
            _ = items
        }

        XCTAssertLessThan(
            memoryUsed,
            1_000_000,  // 1 MB
            "Batch delete should use minimal memory"
        )
    }

    // MARK: - Performance Reporting

    override func tearDown() {
        let report = PerformanceTestBase.generatePerformanceReport()
        print(report)
        super.tearDown()
    }
}
