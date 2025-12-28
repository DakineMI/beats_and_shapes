import XCTest
@testable import BeatsAndShapes

final class AudioEngineTests: XCTestCase {
    
    var audioEngine: AudioEngine!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine(bpm: 120.0)
    }
    
    override func tearDown() {
        audioEngine = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testAudioEngineInitialization() {
        XCTAssertNotNil(audioEngine)
        XCTAssertEqual(audioEngine.isAudioPlaying, false)
    }
    
    func testAudioEngineWithAudioFile() {
        let audioEngineWithFile = AudioEngine(bpm: 120.0, audioFileName: "nonexistent")
        XCTAssertNotNil(audioEngineWithFile)
    }
    
    // MARK: - Beat State Tests
    func testBeatStateDeterminism() {
        let state1 = audioEngine.getBeatState(index: 0)
        let state2 = audioEngine.getBeatState(index: 0)
        
        XCTAssertEqual(state1.kick, state2.kick)
        XCTAssertEqual(state1.snare, state2.snare)
        XCTAssertEqual(state1.hat, state2.hat)
        XCTAssertEqual(state1.bassNote, state2.bassNote)
        XCTAssertEqual(state1.hornTrigger, state2.hornTrigger)
        XCTAssertEqual(state1.fiddleTrigger, state2.fiddleTrigger)
    }
    
    func testBeatStatePatterns() {
        let state0 = audioEngine.getBeatState(index: 0)
        let state1 = audioEngine.getBeatState(index: 1)
        let state2 = audioEngine.getBeatState(index: 2)
        
        // Kick should always be active
        XCTAssertTrue(state0.kick)
        XCTAssertTrue(state1.kick)
        XCTAssertTrue(state2.kick)
        
        // Snare pattern (every other beat)
        XCTAssertFalse(state0.snare)
        XCTAssertTrue(state1.snare)
        XCTAssertFalse(state2.snare)
        
        // Bass note pattern (every 4 beats)
        XCTAssertNotNil(state0.bassNote)
        XCTAssertNil(state1.bassNote)
        XCTAssertNil(state2.bassNote)
        
        // Horn trigger (every 16 beats)
        XCTAssertTrue(state0.hornTrigger)
        XCTAssertFalse(state1.hornTrigger)
        XCTAssertFalse(state2.hornTrigger)
    }
    
    // MARK: - Performance Tests
    func testBeatStatePerformance() {
        measure {
            for i in 0..<10000 {
                _ = audioEngine.getBeatState(index: i)
            }
        }
    }
    
    // MARK: - Memory Tests
    func testAudioEngineMemoryUsage() {
        let initialMemory = getMemoryUsage()
        
        let engines = (0..<100).map { _ in AudioEngine(bpm: 120.0) }
        
        let afterCreationMemory = getMemoryUsage()
        
        engines.forEach { $0.stop() }
        
        let afterCleanupMemory = getMemoryUsage()
        
        let memoryIncrease = afterCreationMemory - initialMemory
        let memoryAfterCleanup = afterCleanupMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024) // Less than 50MB for 100 engines
        XCTAssertLessThan(memoryAfterCleanup, memoryIncrease * 0.1) // Most memory should be freed
    }
    
    // MARK: - Error Handling Tests
    func testAudioEngineWithInvalidAudioFile() {
        let invalidAudioEngine = AudioEngine(bpm: 120.0, audioFileName: "nonexistent_file")
        XCTAssertNotNil(invalidAudioEngine)
        XCTAssertEqual(invalidAudioEngine.isAudioPlaying, false)
    }
    
    // MARK: - Integration Tests
    func testAudioEnginePlayback() {
        audioEngine.playPulse(beatIndex: 0)
        
        // Audio should start playing after first pulse
        XCTAssertEqual(audioEngine.isAudioPlaying, true)
        
        audioEngine.stop()
        XCTAssertEqual(audioEngine.isAudioPlaying, false)
    }
    
    // MARK: - Helper Methods
    private func getMemoryUsage() -> Double {
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
            return Double(info.resident_size)
        }
        return 0
    }
}