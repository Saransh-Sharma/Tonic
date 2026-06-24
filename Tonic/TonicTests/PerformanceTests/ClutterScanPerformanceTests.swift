//
//  ClutterScanPerformanceTests.swift
//  TonicTests
//
//  Performance + size-priority correctness for the clutter scanner that feeds
//  duplicates and large/old files into Smart Scan.
//

import XCTest
import Foundation
@testable import Tonic

final class ClutterScanPerformanceTests: PerformanceTestBase {

    private var tempRoot: URL!

    override func setUpTest() {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ClutterPerf-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownTest() {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func write(_ relativePath: String, bytes: Int, byte: UInt8 = 0x41, modified: Date? = nil) {
        let url = tempRoot.appendingPathComponent(relativePath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(repeating: byte, count: bytes).write(to: url)
        if let modified {
            try? FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    /// A representative tree should scan well within the Smart Scan time budget.
    /// Uses small files with a lowered "large" threshold to keep the fixture light.
    func testQuickClutterScanCompletesWithinBudget() async {
        for i in 0..<300 {
            write("noise/file\(i).dat", bytes: 4096)
        }
        let oldDate = Date().addingTimeInterval(-400 * 24 * 60 * 60)
        for i in 0..<10 {
            write("big/large\(i).bin", bytes: 64 * 1024, modified: oldDate)
        }

        let scanner = ScanCategoryScanner()
        let duration = await measureAsyncExecutionTime {
            _ = await scanner.scanClutterFiles(
                roots: [self.tempRoot.path],
                largeFileThresholdBytes: 32 * 1024
            )
        }

        XCTAssertLessThan(duration, 5.0, "Quick clutter scan of a representative tree should stay well within budget")
    }

    /// The biggest duplicate must survive the hash-candidate cap even when many
    /// smaller same-size candidates are enumerated first (size-priority guarantee).
    func testLargeDuplicateSurvivesHashCandidateCap() async {
        // Many distinct 1 MB files that share sizes, enumerated before the big pair.
        for i in 0..<40 {
            // Pairs of equal size but DIFFERENT content (not duplicates) to flood candidates.
            write("aaa_noise/small\(i)_a.bin", bytes: 1 * 1024 * 1024, byte: UInt8(i % 251))
            write("aaa_noise/small\(i)_b.bin", bytes: 1 * 1024 * 1024, byte: UInt8((i + 7) % 251))
        }
        // One large identical pair (5 MB) in a lexically-later folder.
        write("zzz_big/movie_copy1.mov", bytes: 5 * 1024 * 1024, byte: 0xCD)
        write("zzz_big/movie_copy2.mov", bytes: 5 * 1024 * 1024, byte: 0xCD)

        let scanner = ScanCategoryScanner()
        // Tight hash cap that would be exhausted by the noise if collection were
        // enumeration-ordered rather than size-prioritized.
        let result = await scanner.scanClutterFiles(
            roots: [tempRoot.path],
            duplicateMinFileSizeBytes: 1024,
            maxLargeOldCandidates: 1000,
            maxDuplicateHashCandidates: 12,
            maxDuplicateGroups: 50
        )

        let foundLargeDuplicate = result.duplicateFiles.contains { group in
            group.sizePerFile == 5 * 1024 * 1024 && group.paths.count == 2
        }
        XCTAssertTrue(foundLargeDuplicate, "The largest duplicate pair must be surfaced despite the hash cap")
    }
}
