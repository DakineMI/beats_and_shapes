import SwiftUI
import SpriteKit
import AVFoundation

/// Advanced victory celebration system inspired by Just Shapes & Beats (2025+ standards)
class VictoryCelebrationManager: ObservableObject {
    
    // MARK: - Celebration Types
    enum CelebrationType {
        case perfectRun          // 100% accuracy, no misses
        case highScore           // New high score achieved
        case firstClear          // First time clearing level
        case comboMaster         // Reached maximum combo threshold
        case sRank              // Achieved S grade performance
        case levelComplete        // Standard level completion
        case storyMilestone      // Story progression milestone
        case challengeComplete    // Challenge mode completion
        case comeback            // Comeback from failure
        case speedrun           // Fast completion bonus
    }
    
    enum CelebrationPhase {
        case initial              // Immediate visual feedback (0.5s)
        case buildup              // Building excitement (1.0s)
        case climax               // Peak celebration moment (0.5s)
        case resolution          // Transition back to gameplay (0.5s)
    }
    
    // MARK: - Properties
    @Published private(set) var currentCelebration: CelebrationType?
    @Published private(set) var isCelebrating: Bool = false
    @Published private(set) var comboMultiplier: Int = 1
    @Published private(set) var performanceGrade: String = "C"
    @Published private(set) var celebrationScore: Int = 0
    
    private weak var scene: SKScene?
    private var celebrationTimer: Timer?
    private var currentPhase: CelebrationPhase = .initial
    private var celebrationEffects: [CelebrationEffect] = []
    
    // MARK: - Audio System
    private let celebrationAudioPlayer = AVAudioPlayer()
    
    // MARK: - Visual Effects
    private let celebrationParticles = SKEmitterNode()
    private let celebrationLighting = SKNode()
    private let victoryText = SKLabelNode()
    
    struct CelebrationEffect {
        let type: EffectType
        let node: SKNode
        let duration: TimeInterval
        let timing: TimeInterval
        
        enum EffectType {
            case particles
            case lighting
            case text
            case screenShake
            case colorPulse
        }
    }
    
    init(scene: SKScene) {
        self.scene = scene
        setupCelebrationSystem()
        loadCelebrationAudio()
    }
    
    // MARK: - Setup
    private func setupCelebrationSystem() {
        setupParticles()
        setupLighting()
        setupVictoryText()
        
        // Add to scene
        scene?.addChild(celebrationParticles)
        scene?.addChild(celebrationLighting)
        scene?.addChild(victoryText)
        
        print("✅ Victory celebration system initialized")
    }
    
    private func setupParticles() {
        celebrationParticles.particleTexture = createParticleTexture()
        celebrationParticles.particleBirthRate = 2000
        celebrationParticles.particleLifetime = 2.0
        celebrationParticles.particleSize = CGSize(width: 8, height: 8)
        celebrationParticles.position = CGPoint(x: scene?.frame.midX ?? 0, y: scene?.frame.midY ?? 0)
        celebrationParticles.zPosition = 1000
    }
    
    private func setupLighting() {
        celebrationLighting.fillColor = .white
        celebrationLighting.alpha = 0
        celebrationLighting.zPosition = 999
        
        // Create lighting nodes for dramatic effect
        for i in 0..<4 {
            let lightNode = SKShapeNode(circleOfRadius: 50)
            lightNode.fillColor = .white
            lightNode.alpha = 0
            lightNode.zPosition = 999
            celebrationLighting.addChild(lightNode)
        }
    }
    
    private func setupVictoryText() {
        victoryText.fontSize = 48
        victoryText.fontName = "AvenirNext-Heavy"
        victoryText.fontColor = .white
        victoryText.text = "VICTORY!"
        victoryText.position = CGPoint(x: scene?.frame.midX ?? 0, y: scene?.frame.midY ?? 0)
        victoryText.zPosition = 1001
        victoryText.alpha = 0
    }
    
    private func createParticleTexture() -> SKTexture {
        // Create a celebratory particle texture programmatically
        let size = CGSize(width: 16, height: 16)
        
        UIGraphicsBeginImageContext(size: size)
        let context = UIGraphicsGetCurrentContext()
        
        // Create gradient particle
        let colors = [UIColor.systemYellow, UIColor.systemOrange, UIColor.systemRed, UIColor.white]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map { $0.cgColor }, locations: [0, 1])
        
        context.setFillColor(UIColor.systemYellow.cgColor, alpha: 1.0)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return SKTexture(image: image ?? UIImage())
    }
    
    private func loadCelebrationAudio() {
        // In a real implementation, you'd have celebration sound files
        // For now, we'll create a procedural victory sound
        createVictorySound()
    }
    
    private func createVictorySound() {
        // Create a procedural victory sound using AVAudioEngine
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        // Generate a triumphant sound effect
        let frequency: Float = 523.25 // C5 note
        let duration: TimeInterval = 1.0
        
        let sampleRate = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else {
            return
        }
        
        buffer.frameLength = frameCount
        
        // Generate a simple fanfare sound
        let channels = Int(buffer.format.channelCount)
        for frame in 0..<Int(frameCount) {
            for channel in 0..<channels {
                let time = Double(frame) / Double(sampleRate)
                let sample = sin(2.0 * .pi * frequency * time) * exp(-time * 2.0)
                buffer.floatChannelData![channel][frame] = Float32(sample)
            }
        }
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode)
        
        do {
            try engine.start()
            playerNode.scheduleBuffer(buffer, at: nil, options: [])
            playerNode.play()
        } catch {
            print("❌ Failed to play victory sound: \(error)")
        }
    }
    
    // MARK: - Public Interface
    func triggerCelebration(_ type: CelebrationType, score: Int, accuracy: Float, maxCombo: Int) {
        currentCelebration = type
        isCelebrating = true
        celebrationScore = score
        performanceGrade = calculateGrade(accuracy: accuracy, maxCombo: maxCombo)
        
        // Start celebration sequence
        startCelebrationSequence()
        
        // Log celebration for analytics
        logCelebration(type, score: score, accuracy: accuracy, maxCombo: maxCombo)
    }
    
    func triggerComboCelebration(combo: Int) {
        comboMultiplier = combo
        
        if combo >= 10 {
            createComboEffect(comboLevel: .legendary)
        } else if combo >= 5 {
            createComboEffect(comboLevel: .epic)
        } else if combo >= 3 {
            createComboEffect(comboLevel: .great)
        } else {
            createComboEffect(comboLevel: .good)
        }
    }
    
    private func calculateGrade(accuracy: Float, maxCombo: Int) -> String {
        let accuracyScore = accuracy >= 0.98 ? 1.0 : accuracy >= 0.95 ? 0.9 : accuracy >= 0.90 ? 0.8 : accuracy >= 0.80 ? 0.6 : 0.4
        let comboScore = maxCombo >= 50 ? 1.0 : maxCombo >= 25 ? 0.8 : maxCombo >= 10 ? 0.6 : maxCombo >= 5 ? 0.4 : 0.2
        
        let totalScore = (accuracyScore * 0.6 + comboScore * 0.4) * 100
        
        switch totalScore {
        case 95...100: return "S"
        case 90..<95: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        case 50..<60: return "E"
        default: return "F"
        }
    }
    
    // MARK: - Celebration Sequence
    private func startCelebrationSequence() {
        currentPhase = .initial
        
        // Cancel any existing celebration
        celebrationTimer?.invalidate()
        
        // Start multi-phase celebration
        celebrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            self.updateCelebrationPhase()
        }
        
        print("🎉 Started victory celebration sequence")
    }
    
    private func updateCelebrationPhase() {
        let currentTime = CACurrentMediaTime()
        
        switch currentPhase {
        case .initial:
            executeInitialPhase()
            currentPhase = .buildup
            
        case .buildup:
            executeBuildupPhase()
            
        case .climax:
            executeClimaxPhase()
            
        case .resolution:
            executeResolutionPhase()
            isCelebrating = false
            currentCelebration = nil
            
            celebrationTimer?.invalidate()
            celebrationTimer = nil
        }
    }
    
    private func executeInitialPhase() {
        guard let scene = scene else { return }
        
        // Immediate visual feedback
        createScreenShake(intensity: 0.3, duration: 0.5)
        createColorPulse(color: .systemYellow, duration: 0.5)
        
        // Show victory text
        victoryText.alpha = 1.0
        victoryText.run(SKAction.scale(to: 1.5, duration: 0.3))
        victoryText.run(SKAction.scale(to: 1.0, duration: 0.3))
        
        // Play initial sound cue
        playSoundCue(type: .victoryFanfare)
        
        print("🎯 Initial phase executed")
    }
    
    private func executeBuildupPhase() {
        guard let scene = scene else { return }
        
        // Building excitement
        createCelebrationParticles(count: 500)
        createDramaticLighting(intensity: 0.7)
        
        // Show score breakdown
        showScoreBreakdown()
        
        // Play building music
        playSoundCue(type: .buildupMusic)
        
        print("📈 Buildup phase executed")
    }
    
    private func executeClimaxPhase() {
        guard let scene = scene else { return }
        
        // Peak celebration moment
        createCelebrationParticles(count: 1000)
        createDramaticLighting(intensity: 1.0)
        createScreenShake(intensity: 0.8, duration: 0.3)
        
        // Show grade and stats
        showPerformanceStats()
        
        // Play climax sound
        playSoundCue(type: .climaxFanfare)
        
        print("🎊 Climax phase executed")
    }
    
    private func executeResolutionPhase() {
        guard let scene = scene else { return }
        
        // Transition back to gameplay
        victoryText.alpha = 0
        victoryText.text = ""
        
        clearCelebrationParticles()
        fadeOutLighting()
        
        // Play resolution sound
        playSoundCue(type: .resolutionSound)
        
        print("✨ Resolution phase executed")
    }
    
    // MARK: - Effect Implementations
    private func createScreenShake(intensity: CGFloat, duration: TimeInterval) {
        guard let scene = scene else { return }
        
        let shakeAction = SKAction.sequence([
            SKAction.moveBy(x: intensity * 20, y: 0, duration: duration * 0.25),
            SKAction.moveBy(x: -intensity * 40, y: 0, duration: duration * 0.25),
            SKAction.moveBy(x: intensity * 30, y: 0, duration: duration * 0.25),
            SKAction.moveBy(x: -intensity * 20, y: 0, duration: duration * 0.25)
        ])
        
        scene.run(shakeAction)
    }
    
    private func createColorPulse(color: SKColor, duration: TimeInterval) {
        guard let scene = scene else { return }
        
        let pulseAction = SKAction.sequence([
            SKAction.colorize(with: color, colorBlendFactor: 0.8, duration: duration * 0.2),
            SKAction.wait(forDuration: duration * 0.6),
            SKAction.colorize(with: color, colorBlendFactor: 0, duration: duration * 0.2)
        ])
        
        scene.run(pulseAction)
    }
    
    private func createCelebrationParticles(count: Int) {
        celebrationParticles.numParticlesToEmit = UInt32(count)
        celebrationParticles.resetSimulation()
        
        let emitAction = SKAction.run {
            self.celebrationParticles.particleBirthRate = 0
        }
        
        let resetAction = SKAction.wait(forDuration: 3.0)
        
        let restartAction = SKAction.run {
            self.celebrationParticles.particleBirthRate = 0
            self.celebrationParticles.resetSimulation()
        }
        
        celebrationParticles.run(SKAction.sequence([emitAction, resetAction]))
    }
    
    private func createDramaticLighting(intensity: CGFloat) {
        let fadeIn = SKAction.fadeAlpha(to: intensity, duration: 0.2)
        celebrationLighting.run(fadeIn)
    }
    
    private func fadeOutLighting() {
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 1.0)
        celebrationLighting.run(fadeOut)
    }
    
    private func createComboEffect(comboLevel: ComboLevel) {
        switch comboLevel {
        case .good:
            createScreenShake(intensity: 0.2, duration: 0.2)
            createColorPulse(color: .systemGreen, duration: 0.3)
            
        case .great:
            createScreenShake(intensity: 0.4, duration: 0.3)
            createColorPulse(color: .systemBlue, duration: 0.4)
            
        case .epic:
            createScreenShake(intensity: 0.6, duration: 0.4)
            createColorPulse(color: .systemPurple, duration: 0.5)
            createCelebrationParticles(count: 200)
            
        case .legendary:
            createScreenShake(intensity: 0.8, duration: 0.5)
            createColorPulse(color: .systemRed, duration: 0.6)
            createCelebrationParticles(count: 500)
        }
    }
    
    enum ComboLevel {
        case good, great, epic, legendary
    }
    
    // MARK: - UI Elements
    private func showScoreBreakdown() {
        guard let scene = scene else { return }
        
        let scoreLabel = SKLabelNode(text: "Score: \(celebrationScore)")
        scoreLabel.fontSize = 32
        scoreLabel.fontColor = .white
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.position = CGPoint(x: scene.frame.midX, y: scene.frame.midY + 100)
        scoreLabel.zPosition = 1002
        scoreLabel.alpha = 0
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        scoreLabel.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
        scene.addChild(scoreLabel)
    }
    
    private func showPerformanceStats() {
        guard let scene = scene else { return }
        
        let statsText = """
        Grade: \(performanceGrade)
        Max Combo: \(comboMultiplier)x
        Score: \(celebrationScore)
        """
        
        let statsLabel = SKLabelNode(text: statsText)
        statsLabel.fontSize = 24
        statsLabel.fontColor = .white
        statsLabel.fontName = "AvenirNext-Bold"
        statsLabel.position = CGPoint(x: scene.frame.midX, y: scene.frame.midY - 100)
        statsLabel.zPosition = 1002
        statsLabel.alpha = 0
        
        let scaleAction = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        statsLabel.run(SKAction.group([scaleAction, fadeIn]))
        statsLabel.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), wait, fadeOut, remove]))
        scene.addChild(statsLabel)
    }
    
    private func clearCelebrationParticles() {
        celebrationParticles.numParticlesToEmit = 0
        celebrationParticles.resetSimulation()
    }
    
    // MARK: - Audio System
    private func playSoundCue(type: SoundCueType) {
        // In implementation, you'd play actual sound files
        print("🎵 Playing sound cue: \(type)")
    }
    
    enum SoundCueType {
        case victoryFanfare
        case buildupMusic
        case climaxFanfare
        case resolutionSound
    }
    
    // MARK: - Analytics
    private func logCelebration(_ type: CelebrationType, score: Int, accuracy: Float, maxCombo: Int) {
        // Log celebration for analytics and player progress tracking
        let celebrationData: [String: Any] = [
            "celebration_type": String(describing: type),
            "score": score,
            "accuracy": accuracy,
            "max_combo": maxCombo,
            "grade_achieved": performanceGrade,
            "timestamp": Date().timeIntervalSince1970,
            "session_duration": getCurrentSessionDuration()
        ]
        
        // Send to analytics system
        NotificationCenter.default.post(
            name: .celebrationTriggered,
            object: nil,
            userInfo: celebrationData
        )
        
        print("📊 Logged celebration: \(type) - Score: \(score), Grade: \(performanceGrade)")
    }
    
    private func getCurrentSessionDuration() -> TimeInterval {
        // Implementation would track actual session duration
        return 0.0 // Placeholder
    }
    
    // MARK: - Cleanup
    deinit {
        celebrationTimer?.invalidate()
        cleanup()
    }
    
    private func cleanup() {
        celebrationParticles.removeFromParent()
        celebrationLighting.removeFromParent()
        victoryText.removeFromParent()
        
        if celebrationAudioPlayer.isPlaying {
            celebrationAudioPlayer.stop()
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let celebrationTriggered = Notification.Name("celebrationTriggered")
    static let comboAchieved = Notification.Name("comboAchieved")
    static let newHighScore = Notification.Name("newHighScore")
}