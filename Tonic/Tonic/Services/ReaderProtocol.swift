//
//  ReaderProtocol.swift
//  Tonic
//
//  Enhanced reader architecture inspired by Stats Master
//  Provides lifecycle management, history tracking, and configurable intervals
//  Task ID: fn-6-i4g.1
//

import Foundation
import OSLog

// MARK: - Reader State

/// Represents the current operational state of a reader
public enum ReaderState: Sendable {
    /// Reader is initialized but not actively reading
    case stopped
    /// Reader is actively polling for data
    case active
    /// Reader is temporarily paused (can be resumed)
    case paused
}

// MARK: - Reader Protocol

/// A protocol for data readers that provide system monitoring data.
///
/// This protocol is inspired by Stats Master's reader pattern but adapted for
/// Tonic's modern Swift concurrency model using `@MainActor` and `@Observable`.
///
/// The `Reader` protocol provides full lifecycle management including:
/// - Configurable update intervals (1-60 seconds)
/// - Optional readers (can be disabled without error)
/// - Popup-only readers (only run when widget popup is open)
/// - History tracking with configurable depth
/// - Callback-based value updates
///
/// Example usage:
/// ```swift
/// final class CPUUsageReader: BaseReader<Double> {
///     override func read() -> Double? {
///         // Fetch CPU usage from IOKit
///         return getCurrentCPUUsage()
///     }
/// }
///
/// let reader = CPUUsageReader(interval: 2.0)
/// reader.callback = { value in
///     print("CPU: \(value ?? 0)%")
/// }
/// reader.start()
/// ```
///
/// - Parameter Output: The type of data the reader produces. Must be `Sendable` for thread safety.
public protocol Reader: AnyObject {
    /// Associated type for the data this reader produces
    associatedtype Output: Sendable

    // MARK: - Configuration Properties

    /// The current value from the most recent read operation
    var value: Output? { get }

    /// Update interval in seconds (nil = no automatic polling)
    ///
    /// Valid range: 1.0 to 60.0 seconds
    /// - When nil: Reader must be manually triggered
    /// - When set: Reader creates its own timer for custom timing
    var interval: TimeInterval? { get set }

    /// Whether this reader is optional (can fail without error)
    ///
    /// Optional readers are used for data that may not be available on all systems:
    /// - GPU data on Intel Macs
    /// - Battery data on desktop Macs
    /// - SMC sensors on systems without SMC
    var isOptional: Bool { get }

    /// Whether this reader only runs when widget popup is visible
    ///
    /// Popup-only readers save resources by only reading when:
    /// - User clicks on the menu bar widget
    /// - The popup/detail view is shown
    ///
    /// Examples: Process lists, detailed sensor readings
    var isPopupOnly: Bool { get }

    /// Whether the reader is currently active and producing data
    var isActive: Bool { get }

    /// Number of history points to track (nil = no history tracking)
    ///
    /// When set, the reader maintains an array of recent values:
    /// - nil: No history (current value only)
    /// - N: Store last N data points
    var historyLimit: Int? { get }

    /// Historical values from previous read operations
    var history: [Output] { get }

    // MARK: - Callback

    /// Closure called when a new value is successfully read
    ///
    /// The callback receives the new value (or nil if read failed for optional reader)
    var callback: ((Output?) -> Void)? { get set }

    // MARK: - Lifecycle Methods

    /// Initialize the reader and set up any required resources
    ///
    /// This method is called once during reader initialization.
    /// Override to set up IOKit connections, file handles, etc.
    func setup()

    /// Perform a single read operation and return the current value
    ///
    /// This method does the actual work of fetching data.
    /// - Returns: The current value, or nil if unavailable (for optional readers)
    /// - Note: This method should not directly update `value` - use `callback()` instead
    func read() -> Output?

    /// Clean up resources when reader is being destroyed
    ///
    /// Override to release IOKit references, close file handles, etc.
    func terminate()

    /// Start the reader (begin polling for data)
    ///
    /// After calling start():
    /// - If `interval` is set: Creates a timer for periodic reads
    /// - Performs an initial read immediately
    func start()

    /// Pause the reader (stop polling but keep state)
    ///
    /// The reader can be resumed by calling `start()` again.
    /// Use this to temporarily disable reading without losing configuration.
    func pause()

    /// Stop the reader and release timer resources
    ///
    /// After calling stop(), the reader must be reconfigured before reuse.
    /// This is more final than `pause()` - it releases timers.
    func stop()

    /// Update the value and trigger callback
    ///
    /// - Parameter value: The new value to set (or nil for optional readers)
    func updateValue(_ value: Output?)

    /// Set a new update interval
    ///
    /// - Parameter interval: New interval in seconds (1-60)
    func setInterval(_ interval: TimeInterval)
}

// MARK: - Default Implementations

public extension Reader {
    /// Default implementation: no setup required
    func setup() {}

    /// Default implementation: no cleanup required
    func terminate() {}

    /// Default implementation: readers are not optional by default
    var isOptional: Bool { false }

    /// Default implementation: readers are not popup-only by default
    var isPopupOnly: Bool { false }

    /// Default implementation: no history tracking
    var historyLimit: Int? { nil }

    /// Default implementation: empty history array
    var history: [Output] { [] }

    /// Default implementation: no callback set
    var callback: ((Output?) -> Void)? {
        get { nil }
        set { /* Base implementation handles this */ }
    }

    /// Default implementation for interval change
    func setInterval(_ interval: TimeInterval) {
        // Clamp to valid range
        let clamped = max(1.0, min(60.0, interval))
        self.interval = clamped
    }
}

// MARK: - Base Reader Class

/// Base implementation of the Reader protocol with common functionality.
///
/// This class provides the core implementation for all system monitoring readers.
/// Subclasses only need to implement the `read()` method with their data fetching logic.
///
/// Key features:
/// - Thread-safe value access via `@MainActor`
/// - Automatic history tracking when `historyLimit` is set
/// - Optional per-reader timer via `Repeater` class
/// - Graceful handling of optional readers
///
/// Example:
/// ```swift
/// @MainActor
/// final class TemperatureReader: BaseReader<Double> {
///     override func read() -> Double? {
///         // Read from SMC
///         return smcReadKey("TC0E")
///     }
/// }
/// ```
@MainActor
open class BaseReader<Output: Sendable>: Reader {

    // MARK: - Public Properties

    /// The most recent value from read operations
    public private(set) var value: Output?

    /// Update interval in seconds (nil = no automatic polling)
    public var interval: TimeInterval?

    /// Whether this reader is optional (can fail without error)
    public let isOptional: Bool

    /// Whether this reader only runs when popup is visible
    public let isPopupOnly: Bool

    /// Whether the reader is currently active
    public private(set) var isActive: Bool = false

    /// Number of history points to track
    public let historyLimit: Int?

    /// Historical values
    public private(set) var history: [Output] = []

    /// Callback for value updates
    public var callback: ((Output?) -> Void)?

    // MARK: - Private Properties

    /// Internal timer for per-reader scheduling (when interval is set)
    private var repeater: Repeater?

    /// Lock state for popup-only readers
    private var isLocked: Bool = true

    /// Unique identifier for this reader
    public let id = UUID()

    /// Logger for debugging
    private let logger = os.Logger(subsystem: "com.tonic.app", category: "BaseReader")

    // MARK: - Initialization

    /// Initialize a new base reader
    ///
    /// - Parameters:
    ///   - interval: Update interval in seconds (nil for no automatic polling)
    ///   - optional: Whether this reader can fail without error
    ///   - popupOnly: Whether this reader only runs when popup is visible
    ///   - historyLimit: Number of history points to track (nil = none)
    ///   - callback: Closure to call when new value is available
    public init(
        interval: TimeInterval? = nil,
        optional: Bool = false,
        popupOnly: Bool = false,
        historyLimit: Int? = nil,
        callback: ((Output?) -> Void)? = nil
    ) {
        self.interval = interval
        self.isOptional = optional
        self.isPopupOnly = popupOnly
        self.historyLimit = historyLimit
        self.callback = callback

        // Perform subclass setup
        setup()

        logger.debug("Initialized \(type(of: self)): interval=\(String(describing: interval)), optional=\(optional), popupOnly=\(popupOnly)")
    }

    deinit {
        terminate()
        repeater?.stop()
    }

    // MARK: - Lifecycle

    open func start() {
        guard !isActive else { return }

        // Handle popup-only readers
        if isPopupOnly && isLocked {
            // Perform single read for initial value, but don't start timer
            Task.detached(priority: .background) { [weak self] in
                await self?.performRead()
            }
            return
        }

        // Set up timer if interval is configured
        if let interval = interval, repeater == nil {
            repeater = Repeater(seconds: Int(interval)) { [weak self] in
                Task { [weak self] in
                    await self?.performRead()
                }
            }
        }

        // Perform initial read
        Task.detached(priority: .background) { [weak self] in
            await self?.performRead()
        }

        // Start the timer
        repeater?.start()
        isActive = true

        logger.debug("Started \(type(of: self))")
    }

    open func pause() {
        guard isActive else { return }
        repeater?.pause()
        isActive = false
        logger.debug("Paused \(type(of: self))")
    }

    open func stop() {
        repeater?.stop()
        repeater = nil
        isActive = false
        isLocked = true
        logger.debug("Stopped \(type(of: self))")
    }

    // MARK: - Public Methods

    public func updateValue(_ newValue: Output?) {
        // Update stored value
        self.value = newValue

        // Add to history if tracking is enabled
        if let limit = historyLimit, let validValue = newValue {
            history.append(validValue)
            if history.count > limit {
                history.removeFirst()
            }
        }

        // Notify callback
        callback?(newValue)
    }

    public func setInterval(_ interval: TimeInterval) {
        let clamped = max(1.0, min(60.0, interval))
        self.interval = clamped
        repeater?.reset(seconds: Int(clamped), restart: isActive)
        logger.debug("Set interval for \(type(of: self)) to \(clamped)s")
    }

    /// Unlock a popup-only reader so it can actively read
    public func unlock() {
        isLocked = false
        if isPopupOnly && !isActive {
            start()
        }
    }

    /// Lock a popup-only reader (stops automatic reads)
    public func lock() {
        isLocked = true
        if isPopupOnly && isActive {
            pause()
        }
    }

    // MARK: - Subclass Override Point

    /// Subclasses override this to perform actual data reading
    ///
    /// - Returns: The current value, or nil if unavailable
    open func read() -> Output? {
        nil
    }

    // MARK: - Private Methods

    private func performRead() {
        do {
            let newValue = read()

            // For optional readers, nil is acceptable
            if !isOptional && newValue == nil {
                logger.warning("Reader \(type(of: self)) returned nil but is not optional")
            }

            updateValue(newValue)
        } catch {
            if isOptional {
                logger.debug("Optional reader \(type(of: self)) failed: \(error.localizedDescription)")
                updateValue(nil)
            } else {
                logger.error("Reader \(type(of: self)) failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Repeater

/// A simple timer class for periodic task execution.
///
/// Inspired by Stats Master's Repeater class, this provides
/// a lightweight alternative to Timer for reader scheduling.
///
/// Uses DispatchSourceTimer for precise, efficient scheduling.
public final class Repeater: @unchecked Sendable {

    private enum State: Sendable {
        case paused
        case running
    }

    private var state: State = .paused
    private let callback: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.tonic.reader.repeater", qos: .utility)
    private let stateLock = NSLock()

    // Use unsafe mutable reference for DispatchSourceTimer which is not Sendable
    // All access is synchronized via the queue
    private nonisolated(unsafe) var timer: DispatchSourceTimer?

    public init(seconds: Int, callback: @escaping @Sendable () -> Void) {
        self.callback = callback
        setupTimer(seconds: seconds)
    }

    deinit {
        timer?.cancel()
    }

    private func setupTimer(seconds: Int) {
        let newTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        newTimer.schedule(deadline: .now() + .seconds(seconds), repeating: .seconds(seconds), leeway: .milliseconds(100))
        newTimer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            let shouldRun = self.state == .running
            self.stateLock.unlock()
            if shouldRun {
                self.callback()
            }
        }
        self.timer = newTimer
    }

    public func start() {
        queue.sync {
            stateLock.lock()
            guard state == .paused else {
                stateLock.unlock()
                return
            }
            stateLock.unlock()
            timer?.resume()
            stateLock.lock()
            state = .running
            stateLock.unlock()
        }
    }

    public func pause() {
        queue.sync {
            stateLock.lock()
            guard state == .running else {
                stateLock.unlock()
                return
            }
            stateLock.unlock()
            timer?.suspend()
            stateLock.lock()
            state = .paused
            stateLock.unlock()
        }
    }

    public func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            stateLock.lock()
            state = .paused
            stateLock.unlock()
        }
    }

    public func reset(seconds: Int, restart: Bool = false) {
        queue.sync {
            stateLock.lock()
            let wasRunning = state == .running
            stateLock.unlock()

            if wasRunning {
                timer?.suspend()
            }

            timer?.cancel()
            setupTimer(seconds: seconds)

            if restart {
                timer?.resume()
                stateLock.lock()
                state = .running
                stateLock.unlock()
            }
        }
    }
}

// MARK: - Reader Registry

/// A registry for managing multiple readers.
///
/// This provides centralized management of all readers,
/// allowing for batch operations and coordinated lifecycle.
@MainActor
public final class ReaderRegistry: @unchecked Sendable {

    public static let shared = ReaderRegistry()

    /// Type-erased reader wrapper
    private struct AnyReader {
        let start: () -> Void
        let stop: () -> Void
        let pause: () -> Void
    }

    private var readers: [String: AnyReader] = [:]
    private let lock = NSLock()

    private init() {}

    /// Register a reader with a unique identifier
    public func register<R: Reader>(_ reader: R, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        readers[key] = AnyReader(
            start: { reader.start() },
            stop: { reader.stop() },
            pause: { reader.pause() }
        )
    }

    /// Unregister a reader
    public func unregister(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        readers[key]?.stop()
        readers.removeValue(forKey: key)
    }

    /// Start all registered readers
    public func startAll() {
        lock.lock()
        let allReaders = Array(readers.values)
        lock.unlock()

        for reader in allReaders {
            reader.start()
        }
    }

    /// Stop all registered readers
    public func stopAll() {
        lock.lock()
        let allReaders = Array(readers.values)
        lock.unlock()

        for reader in allReaders {
            reader.stop()
        }
    }
}
