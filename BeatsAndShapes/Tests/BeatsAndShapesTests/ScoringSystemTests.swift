import XCTest
@testable import BeatsAndShapes

final class ScoringSystemTests: XCTestCase {
    
    var scoringSystem: ScoringSystem!
    
    override func setUp() {
        super.setUp()
        scoringSystem = ScoringSystem()
    }
    
    override func tearDown() {
        scoringSystem = nil
        super.tearDown()
    }
    
    // MARK: - Hit Registration Tests
    func testPerfectHit() {
        scoringSystem.registerHit(quality: .perfect)
        
        XCTAssertEqual(scoringSystem.score, ScoringSystem.HitQuality.perfect.points)
        XCTAssertEqual(scoringSystem.combo, 1)
        XCTAssertEqual(scoringSystem.maxCombo, 1)
        XCTAssertEqual(scoringSystem.perfectHits, 1)
        XCTAssertEqual(scoringSystem.goodHits, 0)
        XCTAssertEqual(scoringSystem.missedHits, 0)
    }
    
    func testGoodHit() {
        scoringSystem.registerHit(quality: .good)
        
        XCTAssertEqual(scoringSystem.score, ScoringSystem.HitQuality.good.points)
        XCTAssertEqual(scoringSystem.combo, 0)
        XCTAssertEqual(scoringSystem.maxCombo, 0)
        XCTAssertEqual(scoringSystem.perfectHits, 0)
        XCTAssertEqual(scoringSystem.goodHits, 1)
        XCTAssertEqual(scoringSystem.missedHits, 0)
    }
    
    func testMissHit() {
        scoringSystem.registerHit(quality: .miss)
        
        XCTAssertEqual(scoringSystem.score, 0)
        XCTAssertEqual(scoringSystem.combo, 0)
        XCTAssertEqual(scoringSystem.maxCombo, 0)
        XCTAssertEqual(scoringSystem.perfectHits, 0)
        XCTAssertEqual(scoringSystem.goodHits, 0)
        XCTAssertEqual(scoringSystem.missedHits, 1)
    }
    
    // MARK: - Combo Tests
    func testComboBuilding() {
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 1)
        
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 2)
        
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 3)
        
        XCTAssertEqual(scoringSystem.maxCombo, 3)
    }
    
    func testComboBreakOnMiss() {
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 2)
        
        scoringSystem.registerHit(quality: .miss)
        XCTAssertEqual(scoringSystem.combo, 0)
        XCTAssertEqual(scoringSystem.maxCombo, 2)
    }
    
    func testComboReductionOnGoodHit() {
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 2)
        
        scoringSystem.registerHit(quality: .good)
        XCTAssertEqual(scoringSystem.combo, 1)
    }
    
    // MARK: - Accuracy Tests
    func testAccuracyCalculation() {
        // Perfect accuracy
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        
        let accuracy = scoringSystem.getAccuracy()
        XCTAssertEqual(accuracy, 100.0, accuracy: 0.1)
        
        scoringSystem.reset()
        
        // Mixed accuracy
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .good)
        scoringSystem.registerHit(quality: .miss)
        
        let mixedAccuracy = scoringSystem.getAccuracy()
        let expectedAccuracy = (1.0 + 1.0 + 0.5) / 4.0 * 100.0
        XCTAssertEqual(mixedAccuracy, expectedAccuracy, accuracy: 0.1)
    }
    
    func testAccuracyEdgeCases() {
        // No hits yet
        XCTAssertEqual(scoringSystem.getAccuracy(), 0.0)
        
        // All misses
        scoringSystem.registerHit(quality: .miss)
        scoringSystem.registerHit(quality: .miss)
        
        let missAccuracy = scoringSystem.getAccuracy()
        XCTAssertEqual(missAccuracy, 0.0)
    }
    
    // MARK: - Grade Tests
    func testGradeS() {
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.getGrade(), "S")
    }
    
    func testGradeA() {
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .good) // 90% accuracy
        XCTAssertEqual(scoringSystem.getGrade(), "A")
    }
    
    func testGradeB() {
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .good)
        scoringSystem.registerHit(quality: .good) // 66% accuracy
        XCTAssertEqual(scoringSystem.getGrade(), "B")
    }
    
    func testGradeF() {
        scoringSystem.registerHit(quality: .miss)
        XCTAssertEqual(scoringSystem.getGrade(), "F")
    }
    
    // MARK: - Combo Timeout Tests
    func testComboTimeout() {
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.combo, 1)
        
        // Simulate timeout
        scoringSystem.update()
        Thread.sleep(forTimeInterval: 3.0)
        scoringSystem.update()
        
        XCTAssertEqual(scoringSystem.combo, 0)
    }
    
    func testComboTimeoutDoesNotResetMaxCombo() {
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .perfect)
        XCTAssertEqual(scoringSystem.maxCombo, 2)
        
        // Simulate timeout
        Thread.sleep(forTimeInterval: 3.0)
        scoringSystem.update()
        
        XCTAssertEqual(scoringSystem.combo, 0)
        XCTAssertEqual(scoringSystem.maxCombo, 2)
    }
    
    // MARK: - Reset Tests
    func testReset() {
        scoringSystem.registerHit(quality: .perfect)
        scoringSystem.registerHit(quality: .good)
        scoringSystem.registerHit(quality: .miss)
        
        XCTAssertFalse(scoringSystem.score == 0)
        XCTAssertFalse(scoringSystem.combo == 0)
        XCTAssertFalse(scoringSystem.perfectHits == 0)
        
        scoringSystem.reset()
        
        XCTAssertEqual(scoringSystem.score, 0)
        XCTAssertEqual(scoringSystem.combo, 0)
        XCTAssertEqual(scoringSystem.maxCombo, 0)
        XCTAssertEqual(scoringSystem.perfectHits, 0)
        XCTAssertEqual(scoringSystem.goodHits, 0)
        XCTAssertEqual(scoringSystem.missedHits, 0)
    }
    
    // MARK: - Performance Tests
    func testPerformance() {
        measure {
            for _ in 0..<10000 {
                let qualities: [ScoringSystem.HitQuality] = [.perfect, .good, .miss]
                let randomQuality = qualities.randomElement()!
                scoringSystem.registerHit(quality: randomQuality)
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    func testThreadSafety() {
        let expectation = XCTestExpectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            scoringSystem.registerHit(quality: .perfect)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should handle concurrent access without crashing
        XCTAssertNotNil(scoringSystem.score)
    }
    
    // MARK: - Edge Cases
    func testLargeCombo() {
        let largeCombo = 1000
        
        for _ in 0..<largeCombo {
            scoringSystem.registerHit(quality: .perfect)
        }
        
        XCTAssertEqual(scoringSystem.combo, largeCombo)
        XCTAssertEqual(scoringSystem.maxCombo, largeCombo)
        XCTAssertTrue(scoringSystem.score > 0)
    }
    
    func testScoreOverflow() {
        // Test that score doesn't overflow with large numbers
        for _ in 0..<100000 {
            scoringSystem.registerHit(quality: .perfect)
        }
        
        XCTAssertLessThanOrEqual(scoringSystem.score, Int.max)
    }
}