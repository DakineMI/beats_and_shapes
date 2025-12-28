import XCTest
@testable import BeatsAndShapes
import SpriteKit

final class GameConstantsTests: XCTestCase {
    
    // MARK: - Physics Categories Tests
    func testPhysicsCategoriesValues() {
        XCTAssertEqual(PhysicsCategories.player, 0x1 << 0)
        XCTAssertEqual(PhysicsCategories.obstacle, 0x1 << 1)
        XCTAssertEqual(PhysicsCategories.damageZone, 0x1 << 2)
        
        // Ensure categories don't overlap
        XCTAssertNotEqual(PhysicsCategories.player, PhysicsCategories.obstacle)
        XCTAssertNotEqual(PhysicsCategories.player, PhysicsCategories.damageZone)
        XCTAssertNotEqual(PhysicsCategories.obstacle, PhysicsCategories.damageZone)
    }
    
    // MARK: - Game Constants Tests
    func testGameConstantsValues() {
        XCTAssertEqual(GameConstants.maxObstacles, 12)
        XCTAssertEqual(GameConstants.playerSize, 20)
        XCTAssertEqual(GameConstants.bossSize, 100)
        XCTAssertEqual(GameConstants.sceneWidth, 1024)
        XCTAssertEqual(GameConstants.sceneHeight, 768)
    }
    
    func testTimingConstants() {
        XCTAssertEqual(GameConstants.comboTimeout, 2.0)
        XCTAssertEqual(GameConstants.obstacleLifetime, 0.5)
        XCTAssertEqual(GameConstants.fadeDuration, 0.2)
        XCTAssertEqual(GameConstants.dashDuration, 0.1)
    }
    
    func testMovementConstants() {
        XCTAssertEqual(GameConstants.backgroundSpeed, 300)
        XCTAssertEqual(GameConstants.dashDistance, 180)
    }
    
    // MARK: - Colors Tests
    func testGameColors() {
        XCTAssertEqual(GameConstants.Colors.player, SKColor.cyan)
        XCTAssertEqual(GameConstants.Colors.obstacle, SKColor.red)
        XCTAssertEqual(GameConstants.Colors.background, SKColor.black)
        XCTAssertEqual(GameConstants.Colors.text, SKColor.white)
        XCTAssertEqual(GameConstants.Colors.unlocked, SKColor.cyan)
        XCTAssertEqual(GameConstants.Colors.locked, SKColor.gray)
        XCTAssertEqual(GameConstants.Colors.health, SKColor.white)
    }
    
    // MARK: - Fonts Tests
    func testGameFonts() {
        XCTAssertEqual(GameConstants.Fonts.heavy, "AvenirNext-Heavy")
        XCTAssertEqual(GameConstants.Fonts.bold, "AvenirNext-Bold")
        XCTAssertEqual(GameConstants.Fonts.medium, "AvenirNext-Medium")
    }
    
    // MARK: - File Extensions Tests
    func testFileExtensions() {
        let audioExtensions = GameConstants.FileExtensions.audio
        XCTAssertTrue(audioExtensions.contains("mp3"))
        XCTAssertTrue(audioExtensions.contains("m4a"))
        XCTAssertTrue(audioExtensions.contains("wav"))
        XCTAssertTrue(audioExtensions.contains("aac"))
        XCTAssertEqual(audioExtensions.count, 4)
        
        let videoExtensions = GameConstants.FileExtensions.video
        XCTAssertEqual(videoExtensions, "mp4")
    }
    
    // MARK: - Instrument ID Tests
    func testInstrumentIDValues() {
        let allInstruments = InstrumentID.allCases
        XCTAssertEqual(allInstruments.count, 8)
        
        XCTAssertEqual(InstrumentID.kick.rawValue, 0)
        XCTAssertEqual(InstrumentID.snare.rawValue, 1)
        XCTAssertEqual(InstrumentID.hat.rawValue, 2)
        XCTAssertEqual(InstrumentID.bass1.rawValue, 3)
        XCTAssertEqual(InstrumentID.bass2.rawValue, 4)
        XCTAssertEqual(InstrumentID.bass3.rawValue, 5)
        XCTAssertEqual(InstrumentID.bass4.rawValue, 6)
        XCTAssertEqual(InstrumentID.horn.rawValue, 7)
    }
    
    func testInstrumentDurations() {
        XCTAssertEqual(InstrumentID.kick.duration, 0.3)
        XCTAssertEqual(InstrumentID.snare.duration, 0.15)
        XCTAssertEqual(InstrumentID.hat.duration, 0.05)
        XCTAssertEqual(InstrumentID.bass1.duration, 0.4)
        XCTAssertEqual(InstrumentID.bass2.duration, 0.4)
        XCTAssertEqual(InstrumentID.bass3.duration, 0.4)
        XCTAssertEqual(InstrumentID.bass4.duration, 0.4)
        XCTAssertEqual(InstrumentID.horn.duration, 0.5)
    }
    
    // MARK: - Validation Helper Tests
    func testValidateAPIKey() {
        // Invalid API keys
        XCTAssertFalse(ValidationHelper.validateAPIKey(""))
        XCTAssertFalse(ValidationHelper.validateAPIKey("short"))
        XCTAssertFalse(ValidationHelper.validateAPIKey("1234567890123456789")) // 19 chars
        
        // Valid API keys
        XCTAssertTrue(ValidationHelper.validateAPIKey("12345678901234567890")) // 20 chars
        XCTAssertTrue(ValidationHelper.validateAPIKey("valid_api_key_1234567890"))
        XCTAssertTrue(ValidationHelper.validateAPIKey("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")) // JWT token
    }
    
    func testValidateFileName() {
        // Invalid file names
        XCTAssertFalse(ValidationHelper.validateFileName(""))
        XCTAssertFalse(ValidationHelper.validateFileName("../dangerous"))
        XCTAssertFalse(ValidationHelper.validateFileName("../../../etc/passwd"))
        XCTAssertFalse(ValidationHelper.validateFileName("file/../../path"))
        
        // Valid file names
        XCTAssertTrue(ValidationHelper.validateFileName("safe_file"))
        XCTAssertTrue(ValidationHelper.validateFileName("audio.mp3"))
        XCTAssertTrue(ValidationHelper.validateFileName("music_file.wav"))
        XCTAssertTrue(ValidationHelper.validateFileName("my-song.mp3"))
        XCTAssertTrue(ValidationHelper.validateFileName("song_with_underscores.m4a"))
    }
    
    func testSanitizeInput() {
        // Test trimming
        XCTAssertEqual(ValidationHelper.sanitizeInput("  test  "), "test")
        XCTAssertEqual(ValidationHelper.sanitizeInput("\tinput\n"), "input")
        XCTAssertEqual(ValidationHelper.sanitizeInput("  spaced input  "), "spaced input")
        
        // Test dangerous path removal
        XCTAssertEqual(ValidationHelper.sanitizeInput("dangerous../path"), "dangerouspath")
        XCTAssertEqual(ValidationHelper.sanitizeInput("file/../../dangerous"), "file/dangerous")
        XCTAssertEqual(ValidationHelper.sanitizeInput("../../../etc/passwd"), "etc/passwd")
        
        // Test normal input
        XCTAssertEqual(ValidationHelper.sanitizeInput("normal_input"), "normal_input")
        XCTAssertEqual(ValidationHelper.sanitizeInput("file.mp3"), "file.mp3")
    }
    
    // MARK: - Game Error Tests
    func testGameErrorDescriptions() {
        let audioError = GameError.audioFileNotFound("test.mp3")
        XCTAssertEqual(audioError.localizedDescription, "Audio file not found: test.mp3")
        
        let setupError = GameError.audioEngineSetupFailed(NSError(domain: "test", code: 1, userInfo: nil))
        XCTAssertTrue(setupError.localizedDescription.contains("Audio engine setup failed"))
        
        let apiError = GameError.invalidAPIKey
        XCTAssertEqual(apiError.localizedDescription, "Invalid API key provided")
        
        let networkError = GameError.networkRequestFailed(NSError(domain: "network", code: 404, userInfo: nil))
        XCTAssertTrue(networkError.localizedDescription.contains("Network request failed"))
        
        let persistenceError = GameError.scorePersistenceFailed(NSError(domain: "persistence", code: 2, userInfo: nil))
        XCTAssertTrue(persistenceError.localizedDescription.contains("Failed to save score"))
    }
    
    // MARK: - Edge Cases Tests
    func testConstantsConsistency() {
        // Ensure scene dimensions match aspect ratio expectations
        let aspectRatio = GameConstants.sceneWidth / GameConstants.sceneHeight
        XCTAssertEqual(aspectRatio, 1024/768, accuracy: 0.01)
        
        // Ensure timing constants are positive
        XCTAssertGreaterThan(GameConstants.comboTimeout, 0)
        XCTAssertGreaterThan(GameConstants.obstacleLifetime, 0)
        XCTAssertGreaterThan(GameConstants.fadeDuration, 0)
        
        // Ensure size constants are positive
        XCTAssertGreaterThan(GameConstants.playerSize, 0)
        XCTAssertGreaterThan(GameConstants.bossSize, 0)
        XCTAssertGreaterThan(GameConstants.maxObstacles, 0)
    }
    
    func testInstrumentDurationsConsistency() {
        let allInstruments = InstrumentID.allCases
        
        // All durations should be positive
        for instrument in allInstruments {
            XCTAssertGreaterThan(instrument.duration, 0)
        }
        
        // Certain patterns should hold
        XCTAssertLessThan(InstrumentID.hat.duration, InstrumentID.snare.duration)
        XCTAssertLessThan(InstrumentID.snare.duration, InstrumentID.kick.duration)
        XCTAssertLessThan(InstrumentID.kick.duration, InstrumentID.horn.duration)
    }
    
    // MARK: - Performance Tests
    func testValidationPerformance() {
        let testInputs = Array(repeating: "test_api_key_1234567890", count: 10000)
        
        measure {
            for input in testInputs {
                _ = ValidationHelper.validateAPIKey(input)
            }
        }
    }
    
    func testSanitizationPerformance() {
        let testInputs = Array(repeating: "  test../input  ", count: 10000)
        
        measure {
            for input in testInputs {
                _ = ValidationHelper.sanitizeInput(input)
            }
        }
    }
}