import Foundation
import SpriteKit

// MARK: - Physics Categories
struct PhysicsCategories {
    static let player: UInt32 = 0x1 << 0
    static let obstacle: UInt32 = 0x1 << 1
    static let damageZone: UInt32 = 0x1 << 2
}

// MARK: - Game Constants
struct GameConstants {
    static let maxObstacles = 12
    static let playerSize: CGFloat = 20
    static let bossSize: CGFloat = 100
    static let beamWidth: CGFloat = 30
    static let beamHeight: CGFloat = 4000
    static let pulsarRadius: CGFloat = 10
    static let aimedShotSize: CGFloat = 20
    
    // Movement speeds
    static let backgroundSpeed: CGFloat = 300
    static let dashDistance: CGFloat = 180
    static let dashDuration: TimeInterval = 0.1
    
    // Timing
    static let comboTimeout: TimeInterval = 2.0
    static let obstacleLifetime: TimeInterval = 0.5
    static let fadeDuration: TimeInterval = 0.2
    
    // UI dimensions
    static let sceneWidth: CGFloat = 1024
    static let sceneHeight: CGFloat = 768
    static let buttonCornerRadius: CGFloat = 8
    static let buttonHeight: CGFloat = 75
    
    // Scoring
    static let baseScorePerBeat = 10
    static let perfectHitScore = 100
    static let goodHitScore = 50
    static let maxComboMultiplier = 10
    
    // Boss battle
    static let bossAppearBeatsRemaining = 64
    static let bossAttackRange = 1200
    static let bossAttackDuration: TimeInterval = 1.5
    static let bossWaveRadius = 50.0
    static let bossWaveDuration: TimeInterval = 0.8
    static let bossDamageZoneRadius = 500.0
    
    // Visual effects
    static let playerDashGhosts = 3
    static let playerDashGhostDelay: TimeInterval = 0.03
    static let playerPulseScale = 1.2
    static let playerPulseDuration: TimeInterval = 0.05
    
    // Audio
    static let sampleRate: Double = 44100.0
    static let reverbWetDryMix: Float = 30
    static let delayWetDryMix: Float = 15
    static let delayTime: TimeInterval = 0.375
    static let delayFeedback: Float = 20
    
    // Colors
    struct Colors {
        static let player = SKColor.cyan
        static let obstacle = SKColor.red
        static let background = SKColor.black
        static let text = SKColor.white
        static let unlocked = SKColor.cyan
        static let locked = SKColor.gray
        static let health = SKColor.white
    }
    
    // Fonts
    struct Fonts {
        static let heavy = "AvenirNext-Heavy"
        static let bold = "AvenirNext-Bold"
        static let medium = "AvenirNext-Medium"
    }
    
    // File extensions
    struct FileExtensions {
        static let audio = ["mp3", "m4a", "wav", "aac"]
        static let video = "mp4"
    }
}

// MARK: - Audio Instrument IDs
enum InstrumentID: Int, CaseIterable {
    case kick = 0
    case snare = 1
    case hat = 2
    case bass1 = 3
    case bass2 = 4
    case bass3 = 5
    case bass4 = 6
    case horn = 7
    
    var duration: Double {
        switch self {
        case .kick: return 0.3
        case .snare: return 0.15
        case .hat: return 0.05
        case .bass1, .bass2, .bass3, .bass4: return 0.4
        case .horn: return 0.5
        }
    }
}

// MARK: - Error Types
enum GameError: Error, LocalizedError {
    case audioFileNotFound(String)
    case audioEngineSetupFailed(Error)
    case invalidAPIKey
    case networkRequestFailed(Error)
    case scorePersistenceFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .audioFileNotFound(let fileName):
            return "Audio file not found: \(fileName)"
        case .audioEngineSetupFailed(let error):
            return "Audio engine setup failed: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .networkRequestFailed(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .scorePersistenceFailed(let error):
            return "Failed to save score: \(error.localizedDescription)"
        }
    }
}

// MARK: - Validation Helpers
struct ValidationHelper {
    static func validateAPIKey(_ apiKey: String) -> Bool {
        return !apiKey.isEmpty && apiKey.count >= 20
    }
    
    static func validateFileName(_ fileName: String) -> Bool {
        return !fileName.isEmpty && !fileName.contains("..")
    }
    
    static func sanitizeInput(_ input: String) -> String {
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "..", with: "")
    }
}