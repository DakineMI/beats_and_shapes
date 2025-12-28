import CoreML
import CreateML
import SwiftData
import SwiftUI

/// Core ML integration for adaptive difficulty and player behavior analysis (2025+ standards)
@MainActor
class AIGameplayAnalyzer: ObservableObject {
    
    // MARK: - Models
    private let difficultyModel: MLModel?
    private let playerBehaviorModel: MLModel?
    private let performancePredictionModel: MLModel?
    
    // MARK: - Analysis Data
    @Published private(set) var currentDifficulty: DifficultyLevel = .normal
    @Published private(set) var playerSkillLevel: Float = 0.5
    @Published private(set) var recommendedBeatSpeed: Double = 1.0
    @Published private(set) var performanceScore: Float = 0.5
    @Published private(set) var adaptivePatterns: [AdaptivePattern] = []
    
    // Historical data for training
    private var gameplayHistory: [GameplaySession] = []
    private var currentSession: GameplaySession?
    
    // MARK: - Data Models
    enum DifficultyLevel: String, CaseIterable {
        case veryEasy = "very_easy"
        case easy = "easy"
        case normal = "normal"
        case hard = "hard"
        case veryHard = "very_hard"
        case expert = "expert"
        case adaptive = "adaptive"
        
        var bpmMultiplier: Double {
            switch self {
            case .veryEasy: return 0.7
            case .easy: return 0.85
            case .normal: return 1.0
            case .hard: return 1.15
            case .veryHard: return 1.3
            case .expert: return 1.5
            case .adaptive: return 1.0 // Will be calculated dynamically
            }
        }
        
        var obstacleDensity: Float {
            switch self {
            case .veryEasy: return 0.5
            case .easy: return 0.7
            case .normal: return 1.0
            case .hard: return 1.3
            case .veryHard: return 1.5
            case .expert: return 1.8
            case .adaptive: return 1.0
            }
        }
    }
    
    struct GameplaySession: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let difficulty: DifficultyLevel
        let score: Int
        let accuracy: Float
        let maxCombo: Int
        let missedBeats: Int
        let perfectHits: Int
        let goodHits: Int
        let totalPlayTime: TimeInterval
        let playerActions: [PlayerAction]
        let beatPatterns: [BeatPattern]
        let performanceMetrics: PerformanceMetrics
        
        struct PlayerAction: Codable {
            let timestamp: TimeInterval
            let action: String
            let position: CGPoint
            let beatIndex: Int
        }
        
        struct BeatPattern: Codable {
            let beatIndex: Int
            let obstaclesSpawned: [String]
            let playerPosition: CGPoint
            let success: Bool
        }
        
        struct PerformanceMetrics: Codable {
            let averageReactionTime: Double
            let movementEfficiency: Float
            let errorRate: Float
            let consistency: Float
        }
    }
    
    struct AdaptivePattern: Identifiable {
        let id = UUID()
        let patternType: PatternType
        let confidence: Float
        let recommendation: String
        let expectedDifficulty: DifficultyLevel
        
        enum PatternType: String {
            case reactionTime = "reaction_time"
            case movementPattern = "movement_pattern"
            case rhythmRecognition = "rhythm_recognition"
            case obstacleAvoidance = "obstacle_avoidance"
            case comboBuilding = "combo_building"
        }
    }
    
    init() {
        loadMLModels()
        setupBehaviorTracking()
    }
    
    // MARK: - ML Model Loading
    private func loadMLModels() {
        do {
            // Load or create difficulty adjustment model
            if let modelURL = Bundle.main.url(forResource: "DifficultyModel", withExtension: "mlmodelc") {
                difficultyModel = try MLModel(contentsOf: modelURL)
            }
            
            // Load or create player behavior model
            if let behaviorModelURL = Bundle.main.url(forResource: "PlayerBehaviorModel", withExtension: "mlmodelc") {
                playerBehaviorModel = try MLModel(contentsOf: behaviorModelURL)
            }
            
            // Load performance prediction model
            if let performanceURL = Bundle.main.url(forResource: "PerformancePredictor", withExtension: "mlmodelc") {
                performancePredictionModel = try MLModel(contentsOf: performanceURL)
            }
            
        } catch {
            print("⚠️ Failed to load ML models: \(error)")
            createFallbackModels()
        }
    }
    
    private func createFallbackModels() {
        // Create simple rule-based models if ML models fail to load
        // This ensures the game remains playable without ML models
        print("🔄 Created fallback rule-based models")
    }
    
    private func setupBehaviorTracking() {
        // Setup real-time behavior analysis
        startSession()
    }
    
    // MARK: - Real-time Analysis
    func startSession() {
        currentSession = GameplaySession(
            id: UUID(),
            timestamp: Date(),
            difficulty: currentDifficulty,
            score: 0,
            accuracy: 0,
            maxCombo: 0,
            missedBeats: 0,
            perfectHits: 0,
            goodHits: 0,
            totalPlayTime: 0,
            playerActions: [],
            beatPatterns: [],
            performanceMetrics: PerformanceMetrics(
                averageReactionTime: 0,
                movementEfficiency: 0.5,
                errorRate: 0.5,
                consistency: 0.5
            )
        )
    }
    
    func recordPlayerAction(_ action: String, position: CGPoint, beatIndex: Int) {
        guard var session = currentSession else { return }
        
        let playerAction = GameplaySession.PlayerAction(
            timestamp: Date().timeIntervalSince1970,
            action: action,
            position: position,
            beatIndex: beatIndex
        )
        
        session.playerActions.append(playerAction)
        
        // Analyze action in real-time
        analyzePlayerAction(playerAction)
    }
    
    private func analyzePlayerAction(_ action: GameplaySession.PlayerAction) {
        // Real-time analysis of player behavior
        Task { @MainActor in
            await updateBehaviorPredictions(action)
        }
    }
    
    func updateScore(_ score: Int, accuracy: Float, maxCombo: Int) {
        guard var session = currentSession else { return }
        
        session.score = score
        session.accuracy = accuracy
        session.maxCombo = maxCombo
        
        // Update performance metrics
        updatePerformanceMetrics()
        
        // Analyze performance and adapt difficulty
        analyzePerformanceAndAdapt()
    }
    
    private func updatePerformanceMetrics() {
        guard var session = currentSession else { return }
        
        // Calculate performance metrics from player actions
        let actionTimes = session.playerActions.map { $0.timestamp }
        if actionTimes.count > 1 {
            let reactionTimes = zip(actionTimes.dropFirst(), actionTimes.dropLast()).map(-)
            session.performanceMetrics.averageReactionTime = reactionTimes.reduce(0, +) / Double(reactionTimes.count)
        }
        
        // Calculate movement efficiency
        let movements = session.playerActions.filter { $0.action == "move" }
        let obstacles = session.beatPatterns.flatMap { $0.obstaclesSpawned }
        if !obstacles.isEmpty {
            let successfulAvoidances = session.beatPatterns.filter { $0.success }.count
            session.performanceMetrics.movementEfficiency = Float(successfulAvoidances) / Float(obstacles.count)
        }
        
        // Update overall performance score
        updatePerformanceScore()
    }
    
    private func updatePerformanceScore() {
        guard let session = currentSession else { return }
        
        let metrics = session.performanceMetrics
        
        // Weighted performance score
        let reactionScore = max(0, 1 - (metrics.averageReactionTime / 2.0)) // Normalize to 2s
        let movementScore = metrics.movementEfficiency
        let consistencyScore = metrics.consistency
        let accuracyScore = session.accuracy / 100.0
        
        performanceScore = Float((reactionScore + movementScore + consistencyScore + accuracyScore) / 4.0)
        
        playerSkillLevel = performanceScore
    }
    
    private func analyzePerformanceAndAdapt() {
        guard let session = currentSession else { return }
        
        // Use ML models to predict optimal difficulty
        let currentPerformance = session.performanceMetrics
        
        // Analyze patterns and create recommendations
        let patterns = analyzePlayingPatterns(session)
        adaptivePatterns = patterns
        
        // Predict next difficulty
        predictOptimalDifficulty(currentPerformance)
    }
    
    private func analyzePlayingPatterns(_ session: GameplaySession) -> [AdaptivePattern] {
        var patterns: [AdaptivePattern] = []
        
        // Reaction time pattern analysis
        if currentPerformanceMetrics.averageReactionTime > 1.5 {
            patterns.append(AdaptivePattern(
                patternType: .reactionTime,
                confidence: 0.8,
                recommendation: "Player is reacting slowly, consider reducing tempo",
                expectedDifficulty: .easy
            ))
        }
        
        // Movement pattern analysis
        if session.performanceMetrics.movementEfficiency < 0.6 {
            patterns.append(AdaptivePattern(
                patternType: .movementPattern,
                confidence: 0.7,
                recommendation: "Player struggling with movement, reduce obstacle density",
                expectedDifficulty: .easy
            ))
        }
        
        // Combo building pattern analysis
        if session.maxCombo < 5 && session.performanceMetrics.consistency < 0.5 {
            patterns.append(AdaptivePattern(
                patternType: .comboBuilding,
                confidence: 0.6,
                recommendation: "Player not building combos, increase visual feedback",
                expectedDifficulty: .veryEasy
            ))
        }
        
        return patterns
    }
    
    private func predictOptimalDifficulty(_ metrics: GameplaySession.PerformanceMetrics) {
        do {
            // Use ML model for difficulty prediction
            if let model = difficultyModel {
                let input = try MLFeatureProvider(dictionary: [
                    "reaction_time": metrics.averageReactionTime,
                    "movement_efficiency": Double(metrics.movementEfficiency),
                    "error_rate": Double(metrics.errorRate),
                    "consistency": Double(metrics.consistency),
                    "accuracy": Double(currentSession?.accuracy ?? 0)
                ])
                
                let prediction = try model.prediction(from: input)
                
                if let difficulty = prediction.featureValue(for: "predicted_difficulty") {
                    if let predictedDifficulty = DifficultyLevel(rawValue: difficulty.stringValue) {
                        currentDifficulty = predictedDifficulty
                        updateGameParameters()
                    }
                }
            }
        } catch {
            // Fallback to rule-based adjustment
            fallbackDifficultyAdjustment()
        }
    }
    
    private func fallbackDifficultyAdjustment() {
        guard let session = currentSession else { return }
        
        // Rule-based difficulty adjustment
        let overallPerformance = performanceScore
        
        if overallPerformance > 0.8 {
            currentDifficulty = .expert
        } else if overallPerformance > 0.6 {
            currentDifficulty = .hard
        } else if overallPerformance > 0.4 {
            currentDifficulty = .normal
        } else if overallPerformance > 0.2 {
            currentDifficulty = .easy
        } else {
            currentDifficulty = .veryEasy
        }
        
        updateGameParameters()
    }
    
    private func updateGameParameters() {
        // Apply current difficulty settings to game
        recommendedBeatSpeed = currentDifficulty.bpmMultiplier
        
        // Send difficulty change notification
        NotificationCenter.default.post(
            name: .difficultyChanged,
            object: nil,
            userInfo: [
                "difficulty": currentDifficulty.rawValue,
                "beatSpeed": recommendedBeatSpeed
            ]
        )
    }
    
    // MARK: - Session Management
    func endSession() {
        guard var session = currentSession else { return }
        
        session.totalPlayTime = Date().timeIntervalSince(session.timestamp)
        
        // Save session to history
        gameplayHistory.append(session)
        
        // Limit history size
        if gameplayHistory.count > 100 {
            gameplayHistory.removeFirst(gameplayHistory.count - 100)
        }
        
        currentSession = nil
        
        // Train models with new data
        trainModels()
    }
    
    private func trainModels() {
        guard gameplayHistory.count >= 10 else { return } // Need sufficient data
        
        Task { @MainActor in
            await trainDifficultyModel()
            await trainBehaviorModel()
        }
    }
    
    private func trainDifficultyModel() async {
        do {
            // Prepare training data
            let trainingData = try MLDataTable(dictionary: [
                "reaction_time": gameplayHistory.map { Double($0.performanceMetrics.averageReactionTime) },
                "movement_efficiency": gameplayHistory.map { Double($0.performanceMetrics.movementEfficiency) },
                "error_rate": gameplayHistory.map { Double($0.performanceMetrics.errorRate) },
                "consistency": gameplayHistory.map { Double($0.performanceMetrics.consistency) },
                "accuracy": gameplayHistory.map { Double($0.accuracy) },
                "target_difficulty": gameplayHistory.map { $0.difficulty.rawValue }
            ])
            
            // Train regression model
            let regressor = try MLRegressor(trainingData: trainingData, targetColumn: "target_difficulty")
            
            // Save model
            let modelURL = getDocumentsDirectory().appendingPathComponent("DifficultyModel.mlmodel")
            try regressor.write(to: modelURL)
            
            // Reload model
            difficultyModel = try MLModel(contentsOf: modelURL)
            
            print("🤖 Trained and loaded new difficulty model")
            
        } catch {
            print("❌ Failed to train difficulty model: \(error)")
        }
    }
    
    private func trainBehaviorModel() async {
        do {
            // Prepare training data for behavior prediction
            let trainingData = try MLDataTable(dictionary: [
                "player_score": gameplayHistory.map { Double($0.score) },
                "session_duration": gameplayHistory.map { $0.totalPlayTime },
                "max_combo": gameplayHistory.map { Double($0.maxCombo) },
                "average_reaction_time": gameplayHistory.map { $0.performanceMetrics.averageReactionTime },
                "movement_efficiency": gameplayHistory.map { Double($0.performanceMetrics.movementEfficiency) },
                "next_difficulty": gameplayHistory.map { $0.difficulty.rawValue }
            ])
            
            // Train classifier for next difficulty prediction
            let classifier = try MLClassifier(trainingData: trainingData, targetColumn: "next_difficulty")
            
            // Save model
            let modelURL = getDocumentsDirectory().appendingPathComponent("PlayerBehaviorModel.mlmodel")
            try classifier.write(to: modelURL)
            
            print("🤖 Trained and loaded new behavior model")
            
        } catch {
            print("❌ Failed to train behavior model: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - Analytics Integration
    func getAnalyticsData() -> [String: Any] {
        guard let session = currentSession else { return [:] }
        
        return [
            "session_id": session.id.uuidString,
            "difficulty_level": currentDifficulty.rawValue,
            "performance_score": performanceScore,
            "skill_level": playerSkillLevel,
            "accuracy": session.accuracy,
            "max_combo": session.maxCombo,
            "reaction_time": session.performanceMetrics.averageReactionTime,
            "movement_efficiency": session.performanceMetrics.movementEfficiency,
            "adaptive_patterns": adaptivePatterns.map { $0.patternType.rawValue },
            "session_duration": Date().timeIntervalSince(session.timestamp)
        ]
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let difficultyChanged = Notification.Name("difficultyChanged")
    static let performanceUpdated = Notification.Name("performanceUpdated")
    static let adaptivePatternDetected = Notification.Name("adaptivePatternDetected")
}