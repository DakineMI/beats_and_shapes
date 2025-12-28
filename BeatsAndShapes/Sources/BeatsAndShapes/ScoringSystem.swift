import Foundation
import QuartzCore

class ScoringSystem {
    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var perfectHits: Int = 0
    private(set) var goodHits: Int = 0
    private(set) var missedHits: Int = 0
    
    private var lastHitTime: TimeInterval = 0
    private let comboTimeout: TimeInterval = 2.0
    
    enum HitQuality {
        case perfect
        case good
        case miss
        
        var points: Int {
            switch self {
            case .perfect: return 100
            case .good: return 50
            case .miss: return 0
            }
        }
        
        var comboMultiplier: Double {
            switch self {
            case .perfect: return 1.0
            case .good: return 0.5
            case .miss: return -1.0
            }
        }
    }
    
    func registerHit(quality: HitQuality) {
        let currentTime = CACurrentMediaTime()
        
        switch quality {
        case .perfect:
            perfectHits += 1
            combo += 1
        case .good:
            goodHits += 1
            combo = Int(Double(combo) * quality.comboMultiplier)
        case .miss:
            missedHits += 1
            combo = 0
        }
        
        maxCombo = max(maxCombo, combo)
        
        let comboBonus = min(combo / 10, 10)
        let points = quality.points + (quality.points * comboBonus / 10)
        score += points
        
        lastHitTime = currentTime
        
        print("🎯 \(String(describing: quality).uppercased())! Score: \(score) | Combo: \(combo)x")
    }
    
    func update() {
        let currentTime = CACurrentMediaTime()
        if currentTime - lastHitTime > comboTimeout && combo > 0 {
            print("⏰ Combo timeout! Lost \(combo)x combo")
            combo = 0
        }
    }
    
    func getAccuracy() -> Double {
        let totalHits = perfectHits + goodHits + missedHits
        guard totalHits > 0 else { return 0.0 }
        
        let perfectScore = Double(perfectHits)
        let goodScore = Double(goodHits) * 0.5
        let accuracyScore = (perfectScore + goodScore) / Double(totalHits)
        return min(accuracyScore * 100.0, 100.0)
    }
    
    func getGrade() -> String {
        let accuracy = getAccuracy()
        
        switch accuracy {
        case 95...100: return "S"
        case 90..<95: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }
    
    func reset() {
        score = 0
        combo = 0
        maxCombo = 0
        perfectHits = 0
        goodHits = 0
        missedHits = 0
        lastHitTime = 0
    }
    
    func getStats() -> String {
        return """
        📊 Performance Stats:
        Score: \(score)
        Grade: \(getGrade())
        Accuracy: \(String(format: "%.1f", getAccuracy()))%
        Max Combo: \(maxCombo)x
        Perfect: \(perfectHits) | Good: \(goodHits) | Miss: \(missedHits)
        """
    }
}