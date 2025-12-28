import XCTest
@testable import BeatsAndShapes

final class BeatsAndShapesTests: XCTestCase {
    
    // MARK: - BeatManager Tests
    func testBeatManagerInitialization() {
        let bpm = 120.0
        let beatManager = BeatManager(bpm: bpm)
        
        XCTAssertEqual(beatManager.bpm, bpm)
    }
    
    func testBeatManagerTiming() {
        let beatManager = BeatManager(bpm: 60.0)
        beatManager.start()
        
        let expectation = XCTestExpectation(description: "Beat fires")
        beatManager.onBeat = { beatIndex in
            if beatIndex == 1 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.1)
    }
    
    // MARK: - ScoringSystem Tests
    func testScoringSystemPerfectHit() {
        let scoringSystem = ScoringSystem()
        scoringSystem.registerHit(quality: .perfect)
        
        XCTAssertEqual(scoringSystem.score, ScoringSystem.HitQuality.perfect.points)
        XCTAssertEqual(scoringSystem.combo, 1)
        XCTAssertEqual(scoringSystem.perfectHits, 1)
        XCTAssertEqual(scoringSystem.goodHits, 0)
        XCTAssertEqual(scoringSystem.missedHits, 0)
    }
    
    func testScoringSystemGoodHit() {
        let scoringSystem = ScoringSystem()
        scoringSystem.registerHit(quality: .good)
        
        XCTAssertEqual(scoringSystem.score, ScoringSystem.HitQuality.good.points)
        XCTAssertEqual(scoringSystem.combo, 0)
        XCTAssertEqual(scoringSystem.perfectHits, 0)
        XCTAssertEqual(scoringSystem.goodHits, 1)
    }
    
    func testScoringSystemMissHit() {
        let scoringSystem = ScoringSystem()
        scoringSystem.registerHit(quality: .miss)
        
        XCTAssertEqual(scoringSystem.score, 0)
        XCTAssertEqual(scoringSystem.combo, 0)
        XCTAssertEqual(scoringSystem.missedHits, 1)
    }
    
    func testScoringSystemCombo() {
        let scoringSystem = ScoringSystem()
        
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 1)
        
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 2)
        
        scoringSystem.registerHit(quality: .miss)
        XCTAssertEqual(scoringSystem.combo, 0)
    }
    
    func testScoringSystemAccuracy() {
        let scoringSystem = ScoringSystem()
        
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .good)
        scoringSystem.registerHit(quality: .miss)
        
        let accuracy = scoringSystem.getAccuracy()
        let expectedAccuracy = (1.0 + 1.0 + 0.5) / 4.0 * 100.0
        XCTAssertEqual(accuracy, expectedAccuracy, accuracy: 0.1)
    }
    
    func testScoringSystemGrades() {
        let scoringSystem = ScoringSystem()
        
        // Test S grade (95-100%)
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.getGrade(), "S")
        
        scoringSystem.reset()
        
        // Test F grade
        scoringSystem.registerHit(quality: .miss)
        XCTAssertEqual(scoringSystem.getGrade(), "F")
    }
    
    // MARK: - ProgressManager Tests
    func testProgressManagerHighestUnlocked() {
        ProgressManager.unlockNext(current: 0)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 1)
        
        ProgressManager.unlockNext(current: 1)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 2)
    }
    
    func testProgressManagerHighScore() {
        let songId = "test_song"
        
        // Initial score should be 0
        XCTAssertEqual(ProgressManager.getHighScore(for: songId), 0)
        
        // Save a high score
        ProgressManager.saveScore(150, for: songId)
        XCTAssertEqual(ProgressManager.getHighScore(for: songId), 150)
        
        // Don't overwrite with lower score
        ProgressManager.saveScore(100, for: songId)
        XCTAssertEqual(ProgressManager.getHighScore(for: songId), 150)
        
        // Overwrite with higher score
        ProgressManager.saveScore(200, for: songId)
        XCTAssertEqual(ProgressManager.getHighScore(for: songId), 200)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "high_score_\(songId)")
    }
    
    // MARK: - GameData Tests
    func testGameDataSongs() {
        let songs = GameData.songs
        
        XCTAssertEqual(songs.count, 100)
        
        let firstSong = songs.first!
        XCTAssertEqual(firstSong.id, "s0")
        XCTAssertEqual(firstSong.name, "TRACK 1")
        XCTAssertEqual(firstSong.volume, 1)
        XCTAssertEqual(firstSong.difficulty, "EASY")
        
        let lastSong = songs.last!
        XCTAssertEqual(lastSong.id, "s99")
        XCTAssertEqual(lastSong.name, "TRACK 100")
        XCTAssertEqual(lastSong.volume, 5)
        XCTAssertEqual(lastSong.difficulty, "EXPERT")
    }
    
    // MARK: - AudioEngine Tests
    func testAudioEngineBeatState() {
        let audioEngine = AudioEngine(bpm: 120.0)
        
        let beatState0 = audioEngine.getBeatState(index: 0)
        XCTAssertTrue(beatState0.kick)
        XCTAssertFalse(beatState0.snare)
        XCTAssertTrue(beatState0.hat)
        XCTAssertEqual(beatState0.bassNote, 0)
        XCTAssertTrue(beatState0.leadActive)
        XCTAssertTrue(beatState0.hornTrigger)
        XCTAssertFalse(beatState0.fiddleTrigger)
        
        let beatState1 = audioEngine.getBeatState(index: 1)
        XCTAssertTrue(beatState1.kick)
        XCTAssertTrue(beatState1.snare)
        XCTAssertTrue(beatState1.hat)
        XCTAssertNil(beatState1.bassNote)
        XCTAssertTrue(beatState1.leadActive)
        XCTAssertFalse(beatState1.hornTrigger)
        XCTAssertFalse(beatState1.fiddleTrigger)
    }
    
    // MARK: - Validation Tests
    func testValidationHelper() {
        // API Key validation
        XCTAssertFalse(ValidationHelper.validateAPIKey(""))
        XCTAssertFalse(ValidationHelper.validateAPIKey("short"))
        XCTAssertTrue(ValidationHelper.validateAPIKey("valid_api_key_1234567890"))
        
        // File name validation
        XCTAssertFalse(ValidationHelper.validateFileName(""))
        XCTAssertFalse(ValidationHelper.validateFileName("../dangerous"))
        XCTAssertTrue(ValidationHelper.validateFileName("safe_file"))
        
        // Input sanitization
        XCTAssertEqual(ValidationHelper.sanitizeInput("  test  "), "test")
        XCTAssertEqual(ValidationHelper.sanitizeInput("dangerous../path"), "dangerouspath")
    }
    
    // MARK: - GameConstants Tests
    func testGameConstants() {
        XCTAssertEqual(GameConstants.maxObstacles, 12)
        XCTAssertEqual(GameConstants.playerSize, 20)
        XCTAssertEqual(GameConstants.sceneWidth, 1024)
        XCTAssertEqual(GameConstants.sceneHeight, 768)
        
        XCTAssertEqual(PhysicsCategories.player, 0x1 << 0)
        XCTAssertEqual(PhysicsCategories.obstacle, 0x1 << 1)
        
        XCTAssertEqual(InstrumentID.kick.duration, 0.3)
        XCTAssertEqual(InstrumentID.snare.duration, 0.15)
        XCTAssertEqual(InstrumentID.hat.duration, 0.05)
    }
    
    // MARK: - Error Handling Tests
    func testGameErrorDescriptions() {
        let audioError = GameError.audioFileNotFound("test.mp3")
        XCTAssertEqual(audioError.localizedDescription, "Audio file not found: test.mp3")
        
        let apiError = GameError.invalidAPIKey
        XCTAssertEqual(apiError.localizedDescription, "Invalid API key provided")
    }
}

// MARK: - Performance Tests
extension BeatsAndShapesTests {
    func testScoringSystemPerformance() {
        let scoringSystem = ScoringSystem()
        
        measure {
            for _ in 0..<1000 {
                let qualities: [ScoringSystem.HitQuality] = [.perfect, .good, .miss]
                let randomQuality = qualities.randomElement()!
                scoringSystem.registerHit(quality: randomQuality)
            }
        }
    }
    
    func testAudioEngineBeatStatePerformance() {
        let audioEngine = AudioEngine(bpm: 120.0)
        
        measure {
            for i in 0..<10000 {
                _ = audioEngine.getBeatState(index: i)
            }
        }
    }
}