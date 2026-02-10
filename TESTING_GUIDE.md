# Tonic Testing Guide

## Overview

This document outlines the testing infrastructure, patterns, and best practices for the Tonic project.

**Current Status**: ✅ Testing Framework Setup (T1) Complete
**Coverage Target**: 80% across all modules
**Test Frameworks**: XCTest (native)

## Quick Start

### Run All Tests
```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

### Run Specific Test Suite
```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -destination 'platform=macOS' \
  -only-testing:TonicTests/DesignTokensTests \
  test CODE_SIGNING_ALLOWED=NO
```

### Generate Coverage Report
```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  -resultBundlePath /tmp/test-results \
  -derivedDataPath /tmp/derived-data \
  test CODE_SIGNING_ALLOWED=NO
```

## Distribution Build Matrix Validation

Before submitting changes that touch security/scopes, validate both app targets:

```bash
# Direct target
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO

# Store target
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme TonicStore \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO
```

## Scope and Bookmark Migration Test Set

For Store-access work, run this baseline every time:

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO \
  -only-testing:TonicTests/AccessScopeModelsTests \
  -only-testing:TonicTests/ScopeResolverTests \
  -only-testing:TonicTests/ServiceErrorHandlingTests
```

Why these suites:

- `AccessScopeModelsTests` validates typed scope state/blocked reason behavior and key broker/filesystem access paths.
- `ScopeResolverTests` validates canonical path normalization and best-scope matching behavior.
- `ServiceErrorHandlingTests` validates user-facing error mapping integrity.

## Store Security Regression Checklist

When changing scanners, cleaners, uninstall, or storage hub behavior:

1. Build `Tonic` and `TonicStore` successfully.
2. Ensure no new raw filesystem access bypasses scoped facade in Store-sensitive paths.
3. Ensure typed blocked reasons flow to service/UI layers (`Needs access`, `Limited by macOS`).
4. Ensure scope grant/re-auth flows still function (onboarding, dashboard, preferences).
5. Re-run migration test set above.
6. Run at least one manual Store smoke pass with startup-disk scope authorization.

## Test Organization

```
TonicTests/
├── Utilities/
│   ├── MockData.swift                    # Test data factories
│   ├── ColorAccessibilityHelper.swift    # WCAG accessibility testing
│   └── XCTestCase+Helpers.swift          # Custom test assertions
│
├── DesignSystemTests/
│   └── DesignTokensTests.swift           # Colors, spacing, typography, animations
│
├── ComponentTests/
│   ├── ActionTableTests.swift            # Table component
│   ├── MetricRowTests.swift              # Metric display
│   ├── CardTests.swift                   # Card variants
│   └── PreferenceListTests.swift         # Preference list
│
├── ViewTests/
│   ├── DashboardViewTests.swift
│   ├── MaintenanceViewTests.swift
│   ├── DiskAnalysisViewTests.swift
│   ├── AppInventoryViewTests.swift
│   └── ActivityViewTests.swift
│
└── PerformanceTests/
    ├── PerformanceTestBase.swift         # Performance testing utilities
    ├── ActionTablePerformanceTests.swift
    ├── LaunchPerformanceTests.swift
    ├── ViewRenderTests.swift
    └── MemoryProfileTests.swift
```

## Test Coverage by Module

| Module | Target | Status | Notes |
|--------|--------|--------|-------|
| Design System | 90%+ | ✅ Complete | DesignTokens, colors, spacing, typography |
| Components | 85%+ | 🔄 In Progress | ActionTable, MetricRow, Card, PreferenceList |
| Views | 75%+ | 🔄 In Progress | Dashboard, Maintenance, DiskAnalysis, AppInventory |
| Services | 70%+ | ⏳ Planned | Error handling tests (depends on T6) |
| Utilities | 80%+ | ⏳ Planned | Logger, validators, helpers |

### Scope/Sandbox Critical Areas

The following areas are high-risk and should be included in regression passes for Store-safe behavior:

- `AccessBroker` scope lifecycle, status transitions, and `withAccess(...)`.
- `ScopeResolver` canonicalization and protected path detection.
- `ScopedFileSystem` scoped metadata reads and mutation wrappers.
- Smart Scan / SmartCare access-state propagation into manager views.
- Deep Clean and Storage Hub candidate blocking reasons.
- App inventory/uninstall mutation path consistency.

## Testing Patterns

### 1. Unit Tests
Test individual components and functions in isolation.

```swift
func testComponentRendering() {
    // Arrange
    let mockData = MockData.mockHealthScore(value: 75)

    // Act
    let result = calculateScore(mockData)

    // Assert
    XCTAssertEqual(result, 75)
}
```

### 2. Integration Tests
Test how components work together.

```swift
func testDashboardViewWithRealData() {
    // Create view with mock managers
    let view = DashboardView()

    // Verify interactions and state changes
    XCTAssertTrue(view.isLoaded)
}
```

### 3. Accessibility Tests
Test WCAG compliance and keyboard navigation.

```swift
func testColorContrast() {
    XCTAssertColorContrast(
        foreground: NSColor.black,
        background: NSColor.white,
        minimumRatio: 4.5
    )
}
```

### 4. Performance Tests
Benchmark critical operations.

```swift
func testActionTablePerformance() {
    measure {
        // Code to benchmark
        _ = createTableWithItems(count: 1000)
    }
}
```

## Custom Test Helpers

### ColorAccessibilityHelper
Testing WCAG color contrast compliance.

```swift
// Check WCAG AA compliance (4.5:1 for normal text)
let passes = ColorAccessibilityHelper.meetsWCAG_AA_Text(
    foreground: .black,
    background: .white
)

// Get contrast ratio
let ratio = ColorAccessibilityHelper.contrastRatio(
    foreground: .black,
    background: .white
)
XCTAssertGreaterThanOrEqual(ratio, 4.5)
```

### XCTestCase Extensions
Custom assertions for common test patterns.

```swift
// Assert no error thrown
XCTAssertNoThrow(try someThrowingFunction())

// Assert approximate equality
XCTAssertApproximatelyEqual(45.5, 45.51, accuracy: 0.02)

// Wait for condition
waitForCondition({ someCondition }, timeout: 1.0)

// Measure execution time
let elapsed = measureExecutionTime {
    // Code to measure
}
XCTAssertLessThan(elapsed, 0.5)
```

### MockData
Creating test fixtures.

```swift
let healthScore = MockData.mockHealthScore(value: 85)
let metrics = MockData.mockSystemMetrics()
let appItem = MockData.mockAppItem(name: "TestApp", size: 1000)
let fileList = MockData.mockFileList(count: 100)
```

## Writing Tests

### Before You Start
1. Identify the component/function to test
2. List the critical paths and edge cases
3. Plan the test structure (AAA: Arrange, Act, Assert)

### Example Test
```swift
final class ExampleComponentTests: XCTestCase {

    var sut: ExampleComponent!  // System Under Test

    override func setUp() {
        super.setUp()
        sut = ExampleComponent()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testDefaultState() {
        // Arrange
        let component = ExampleComponent()

        // Assert
        XCTAssertFalse(component.isLoading)
        XCTAssertEqual(component.value, 0)
    }

    func testStateTransition() {
        // Arrange
        let component = ExampleComponent()

        // Act
        component.startLoading()

        // Assert
        XCTAssertTrue(component.isLoading)
    }

    func testErrorHandling() {
        // Arrange
        let component = ExampleComponent()

        // Act & Assert
        XCTAssertThrowsError(try component.performAction(with: nil))
    }
}
```

## Accessibility Testing

### Manual Accessibility Audit
1. Enable VoiceOver: Cmd+F5
2. Navigate using keyboard only (Tab, Arrow keys, Enter, Escape)
3. Verify all controls are announced correctly
4. Check focus order is logical
5. Document issues in ACCESSIBILITY_AUDIT_REPORT.md

### Automated Accessibility Tests
```swift
func testAccessibilityLabels() {
    let view = MyView()

    // All interactive elements should have labels
    XCTAssertNotNil(view.accessibilityLabel)

    // Focus order should be logical
    XCTAssertNotNil(view.accessibilityElements)
}
```

## Performance Testing

### Benchmark Template
```swift
func testPerformance() {
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
        // Code to measure
    }
}
```

### Profiling Tools
- **Xcode Instruments**: Cmd+I
- **Time Profiler**: CPU usage
- **Core Animation**: Frame rate
- **Allocations**: Memory usage
- **Leaks**: Memory leaks

## Continuous Integration

### GitHub Actions
Tests run automatically on:
- Pull requests
- Commits to main
- Releases

Coverage reports are generated and compared with baseline.

## Known Limitations

⚠️ **Current Limitations**:
1. SwiftUI preview tests limited (use integration tests instead)
2. Menu bar widgets require full app context
3. PrivilegedHelperManager requires admin auth (skip in CI)

## Troubleshooting

### Tests Won't Build
```bash
# Clean build cache
xcodebuild clean -scheme Tonic

# Rebuild Xcode cache
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### Module Not Found
Ensure test target has:
- `@testable import Tonic` at top of file
- Tonic framework linked in test target build phases

### Tests Timeout
Increase timeout in test:
```swift
func testLongRunningOperation() {
    let expectation = XCTestExpectation()
    // ...
    wait(for: [expectation], timeout: 10.0)  // Increase timeout
}
```

## Adding New Tests

### Checklist
- [ ] Create test file in appropriate subdirectory
- [ ] Add `@testable import Tonic`
- [ ] Implement setUp() and tearDown()
- [ ] Use AAA pattern (Arrange, Act, Assert)
- [ ] Add test documentation comments
- [ ] Run `xcodebuild test` locally before submitting PR
- [ ] Ensure coverage doesn't decrease
- [ ] Update TESTING_GUIDE.md if needed

### Test Naming Convention
- **Unit tests**: `test<FunctionName><Condition><ExpectedResult>`
- **Integration tests**: `test<UserFlow><ExpectedOutcome>`
- **Performance tests**: `testPerformance<ComponentName>`
- **Accessibility tests**: `testAccessibility<Aspect>`

## Resources

### Apple Documentation
- [XCTest Framework](https://developer.apple.com/documentation/xctest)
- [Accessibility Testing](https://developer.apple.com/documentation/accessibility)
- [Performance Testing](https://developer.apple.com/documentation/xctest/xctestcase/1500625-measure)

### WCAG Standards
- [WCAG 2.1 Contrast (Minimum)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
- [WCAG 2.1 Color](https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html)

## Questions?

If you have questions about testing:
1. Check this guide first
2. Search existing tests for examples
3. Create an issue on GitHub
4. Ask in team discussions

---

**Last Updated**: 2026-01-30
**Test Infrastructure Status**: ✅ Ready for expansion
**Next Step**: Implement component tests (T3)
