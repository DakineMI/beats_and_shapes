import XCTest

/// Test configuration for the BeatsAnd Shapes game suite
final class TestConfiguration: NSObject {
    
    // MARK: - Test Suite Configuration
    static func configure() {
        // Configure test environment
        configureUserDefaults()
        configureAudio()
        configurePerformance()
    }
    
    private static func configureUserDefaults() {
        // Use a separate user defaults suite for tests
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.test.beatsandshapes")
    }
    
    private static func configureAudio() {
        // Disable audio in tests to avoid hardware dependencies
        // This can be expanded based on actual audio system implementation
    }
    
    private static func configurePerformance() {
        // Configure performance measurement thresholds
        // This can be expanded with specific performance criteria
    }
}

/// Base test class for all BeatsAndShapes tests
class BeatsAndShapesBaseTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        TestConfiguration.configure()
        setupTestEnvironment()
    }
    
    override func tearDown() {
        cleanupTestEnvironment()
        super.tearDown()
    }
    
    /// Override in subclasses to provide test-specific setup
    func setupTestEnvironment() {
        // Default setup - override in subclasses
    }
    
    /// Override in subclasses to provide test-specific cleanup
    func cleanupTestEnvironment() {
        // Default cleanup - override in subclasses
    }
}

/// Utilities for testing
class TestUtils {
    
    /// Creates a temporary file for testing
    static func createTempFile(data: Data? = nil) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)
        
        if let data = data {
            try? data.write(to: tempFile)
        } else {
            FileManager.default.createFile(atPath: tempFile.path, contents: nil, attributes: nil)
        }
        
        return tempFile
    }
    
    /// Clean up temporary files
    static func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Measure memory usage before and after an operation
    static func measureMemoryUsage<T>(operation: () throws -> T) rethrows -> (result: T, memoryUsed: Int64) {
        let beforeMemory = getCurrentMemoryUsage()
        let result = try operation()
        let afterMemory = getCurrentMemoryUsage()
        let memoryUsed = afterMemory - beforeMemory
        
        return (result, memoryUsed)
    }
    
    /// Get current memory usage in bytes
    private static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        return 0
    }
    
    /// Assert that two floating point values are approximately equal
    static func assertAlmostEqual(_ a: Double, _ b: Double, tolerance: Double = 0.001, file: StaticString = #filePath, line: UInt = #line) {
        let difference = abs(a - b)
        XCTAssertLessThanOrEqual(difference, tolerance, "Values \(a) and \(b) are not almost equal", file: file, line: line)
    }
    
    /// Create test data for performance testing
    static func createTestData(count: Int) -> [String] {
        return (0..<count).map { "test_item_\($0)" }
    }
}

/// Mock objects for testing
class MockAudioEngine {
    var isPlaying = false
    var currentBeat = 0
    var shouldFailSetup = false
    
    init(shouldFailSetup: Bool = false) {
        self.shouldFailSetup = shouldFailSetup
    }
    
    func play() {
        isPlaying = true
    }
    
    func stop() {
        isPlaying = false
    }
    
    func getBeatState(index: Int) -> MockBeatState {
        return MockBeatState(kick: index % 2 == 0, snare: index % 2 == 1)
    }
}

struct MockBeatState {
    let kick: Bool
    let snare: Bool
    let hat: Bool = true
    let bassNote: Int? = nil
    let leadActive: Bool = true
    let hornTrigger: Bool = false
    let fiddleTrigger: Bool = false
}

/// Performance test utilities
class PerformanceTestUtils {
    
    /// Run a performance test and assert it meets time requirements
    static func assertPerformance<T>(
        operation: () throws -> T,
        maxDuration: TimeInterval,
        description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) rethrows -> T {
        let startTime = CACurrentMediaTime()
        let result = try operation()
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        
        XCTAssertLessThanOrEqual(
            duration,
            maxDuration,
            "\(description) took \(duration)s, expected ≤ \(maxDuration)s",
            file: file,
            line: line
        )
        
        return result
    }
    
    /// Run multiple iterations of an operation and return average time
    static func measureAverageTime<T>(
        iterations: Int,
        operation: () throws -> T
    ) rethrows -> (result: T, averageTime: TimeInterval) {
        var totalTime: TimeInterval = 0
        var lastResult: T?
        
        for _ in 0..<iterations {
            let startTime = CACurrentMediaTime()
            lastResult = try operation()
            let endTime = CACurrentMediaTime()
            totalTime += (endTime - startTime)
        }
        
        let averageTime = totalTime / Double(iterations)
        return (lastResult!, averageTime)
    }
}