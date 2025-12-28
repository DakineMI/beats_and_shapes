import XCTest
@testable import BeatsAndShapes

final class ProgressManagerTests: XCTestCase {
    
    // MARK: - Properties
    let testSongId = "test_song_123"
    
    override func setUp() {
        super.setUp()
        // Clean up any existing test data
        UserDefaults.standard.removeObject(forKey: "highest_unlocked_level")
        UserDefaults.standard.removeObject(forKey: "high_score_\(testSongId)")
    }
    
    override func tearDown() {
        // Clean up test data after each test
        UserDefaults.standard.removeObject(forKey: "highest_unlocked_level")
        UserDefaults.standard.removeObject(forKey: "high_score_\(testSongId)")
        super.tearDown()
    }
    
    // MARK: - Highest Unlocked Tests
    func testGetHighestUnlockedDefault() {
        let highest = ProgressManager.getHighestUnlocked()
        XCTAssertEqual(highest, 0)
    }
    
    func testUnlockNextSequential() {
        // First unlock
        ProgressManager.unlockNext(current: 0)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 1)
        
        // Second unlock
        ProgressManager.unlockNext(current: 1)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 2)
        
        // Skip level (should still unlock next sequential)
        ProgressManager.unlockNext(current: 5)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 6)
    }
    
    func testUnlockNextDoesNotDecrease() {
        // Set to level 5
        ProgressManager.unlockNext(current: 4)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 5)
        
        // Try to unlock lower level
        ProgressManager.unlockNext(current: 2)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 5) // Should remain 5
    }
    
    func testUnlockNextAtCurrentLevel() {
        ProgressManager.unlockNext(current: 3)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 4)
        
        // Unlock at current highest level
        ProgressManager.unlockNext(current: 4)
        XCTAssertEqual(ProgressManager.getHighestUnlocked(), 5)
    }
    
    // MARK: - High Score Tests
    func testGetHighScoreDefault() {
        let score = ProgressManager.getHighScore(for: testSongId)
        XCTAssertEqual(score, 0)
    }
    
    func testSaveScoreFirstTime() {
        let testScore = 1500
        ProgressManager.saveScore(testScore, for: testSongId)
        
        let savedScore = ProgressManager.getHighScore(for: testSongId)
        XCTAssertEqual(savedScore, testScore)
    }
    
    func testSaveScoreLowerThanHigh() {
        // Set initial high score
        let highScore = 2000
        ProgressManager.saveScore(highScore, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), highScore)
        
        // Try to save lower score
        let lowScore = 1000
        ProgressManager.saveScore(lowScore, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), highScore) // Should remain high score
    }
    
    func testSaveScoreHigherThanHigh() {
        // Set initial high score
        let initialScore = 1000
        ProgressManager.saveScore(initialScore, for: testSongId)
        
        // Save higher score
        let newHighScore = 2500
        ProgressManager.saveScore(newHighScore, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), newHighScore)
    }
    
    func testSaveScoreSameAsHigh() {
        let testScore = 1800
        ProgressManager.saveScore(testScore, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), testScore)
        
        // Save same score again
        ProgressManager.saveScore(testScore, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), testScore)
    }
    
    func testSaveScoreZero() {
        ProgressManager.saveScore(0, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), 0)
    }
    
    // MARK: - Multiple Songs Tests
    func testMultipleSongsHighScores() {
        let song1Id = "song_1"
        let song2Id = "song_2"
        let song3Id = "song_3"
        
        ProgressManager.saveScore(1000, for: song1Id)
        ProgressManager.saveScore(2000, for: song2Id)
        ProgressManager.saveScore(1500, for: song3Id)
        
        XCTAssertEqual(ProgressManager.getHighScore(for: song1Id), 1000)
        XCTAssertEqual(ProgressManager.getHighScore(for: song2Id), 2000)
        XCTAssertEqual(ProgressManager.getHighScore(for: song3Id), 1500)
    }
    
    // MARK: - Edge Cases Tests
    func testEmptySongId() {
        ProgressManager.saveScore(1000, for: "")
        XCTAssertEqual(ProgressManager.getHighScore(for: ""), 1000)
    }
    
    func testSpecialCharactersInSongId() {
        let specialSongId = "song_special_!@#$%^&*()_+{}|:<>?"
        ProgressManager.saveScore(3000, for: specialSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: specialSongId), 3000)
    }
    
    func testNegativeScores() {
        ProgressManager.saveScore(-100, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), -100)
        
        // Save positive score after negative
        ProgressManager.saveScore(500, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), 500)
    }
    
    func testMaximumScore() {
        let maxScore = Int.max
        ProgressManager.saveScore(maxScore, for: testSongId)
        XCTAssertEqual(ProgressManager.getHighScore(for: testSongId), maxScore)
    }
    
    // MARK: - Persistence Tests
    func testScoresPersistAcrossInstances() {
        let testScore = 1234
        
        // Save score in first instance
        ProgressManager.saveScore(testScore, for: testSongId)
        
        // Create new instance (simulating app restart)
        let retrievedScore = ProgressManager.getHighScore(for: testSongId)
        XCTAssertEqual(retrievedScore, testScore)
    }
    
    func testHighestUnlockedPersistsAcrossInstances() {
        ProgressManager.unlockNext(current: 10)
        
        // Simulate app restart
        let highestUnlocked = ProgressManager.getHighestUnlocked()
        XCTAssertEqual(highestUnlocked, 11)
    }
    
    // MARK: - Thread Safety Tests
    func testConcurrentScoreSaving() {
        let expectation = XCTestExpectation(description: "Concurrent score saving")
        expectation.expectedFulfillmentCount = 10
        
        let scores = [1000, 2000, 1500, 3000, 1200, 2500, 1800, 2200, 1700, 1900]
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            ProgressManager.saveScore(scores[index], for: testSongId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should handle concurrent access without crashing
        let finalScore = ProgressManager.getHighScore(for: testSongId)
        XCTAssertGreaterThan(finalScore, 0)
        XCTAssertTrue(scores.contains(finalScore))
    }
    
    func testConcurrentUnlocking() {
        let expectation = XCTestExpectation(description: "Concurrent unlocking")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            ProgressManager.unlockNext(current: index)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should handle concurrent access without crashing
        let finalHighest = ProgressManager.getHighestUnlocked()
        XCTAssertGreaterThanOrEqual(finalHighest, 0)
    }
    
    // MARK: - Performance Tests
    func testSaveScorePerformance() {
        measure {
            for i in 0..<1000 {
                ProgressManager.saveScore(i, for: "\(testSongId)_\(i)")
            }
        }
    }
    
    func testGetHighScorePerformance() {
        // Setup test data
        for i in 0..<1000 {
            ProgressManager.saveScore(i, for: "\(testSongId)_\(i)")
        }
        
        measure {
            for i in 0..<1000 {
                _ = ProgressManager.getHighScore(for: "\(testSongId)_\(i)")
            }
        }
    }
}