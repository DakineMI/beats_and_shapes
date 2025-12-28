import Foundation

/// Modern dependency injection container using Swift 5.9 features
@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DependencyContainer, T>
    
    var wrappedValue: T {
        DependencyContainer.shared[keyPath: keyPath]
    }
    
    init(_ keyPath: KeyPath<DependencyContainer, T>) {
        self.keyPath = keyPath
    }
}

/// Dependency container using modern Swift concurrency
@MainActor
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    // MARK: - Audio Services
    @Published lazy var audioEngine: AudioEngineProtocol = AudioEngine()
    
    // MARK: - Game Services  
    @Published lazy var scoringSystem: ScoringSystemProtocol = ScoringSystem()
    @Published lazy var progressManager: ProgressManagerProtocol = ProgressManager()
    @Published lazy var beatManager: BeatManagerProtocol? = nil
    
    // MARK: - UI Services
    @Published lazy var gameSceneManager: GameSceneManagerProtocol = GameSceneManager()
    
    // MARK: - Data Services
    @Published lazy var gameDataRepository: GameDataRepositoryProtocol = GameDataRepository()
    @Published lazy var settingsManager: SettingsManagerProtocol = SettingsManager()
    
    private init() {}
}

/// Protocol-based dependency injection for testability
protocol AudioEngineProtocol: AnyObject {
    var isAudioPlaying: Bool { get }
    func getBeatState(index: Int) -> AudioEngine.BeatState
    func playPulse(beatIndex: Int)
    func stop()
}

extension AudioEngine: AudioEngineProtocol {}

protocol ScoringSystemProtocol: AnyObject {
    var score: Int { get }
    var combo: Int { get }
    var maxCombo: Int { get }
    func registerHit(quality: ScoringSystem.HitQuality)
    func update()
    func reset()
    func getAccuracy() -> Double
    func getGrade() -> String
}

extension ScoringSystem: ScoringSystemProtocol {}

protocol ProgressManagerProtocol: AnyObject {
    static func getHighestUnlocked() -> Int
    static func unlockNext(current: Int)
    static func getHighScore(for songId: String) -> Int
    static func saveScore(_ score: Int, for songId: String)
}

extension ProgressManager: ProgressManagerProtocol {}

protocol BeatManagerProtocol: AnyObject {
    var bpm: Double { get }
    var onBeat: ((Int) -> Void)? { get set }
    func start()
    func update()
}

extension BeatManager: BeatManagerProtocol {}

protocol GameSceneManagerProtocol: AnyObject {
    func showSplash(completion: @escaping () -> Void)
    func showMenu()
    func startGame(with song: Song)
}

protocol GameDataRepositoryProtocol: AnyObject {
    var songs: [Song] { get }
}

extension GameData: GameDataRepositoryProtocol {}

protocol SettingsManagerProtocol: AnyObject {
    var musicVolume: Float { get set }
    var soundEffectsVolume: Float { get set }
    var masterVolume: Float { get set }
}

@MainActor
class SettingsManager: ObservableObject, SettingsManagerProtocol {
    @Published var musicVolume: Float = UserDefaults.standard.float(forKey: "music_volume") {
        didSet { UserDefaults.standard.set(musicVolume, forKey: "music_volume") }
    }
    
    @Published var soundEffectsVolume: Float = UserDefaults.standard.float(forKey: "sfx_volume") {
        didSet { UserDefaults.standard.set(soundEffectsVolume, forKey: "sfx_volume") }
    }
    
    @Published var masterVolume: Float = UserDefaults.standard.float(forKey: "master_volume") {
        didSet { UserDefaults.standard.set(masterVolume, forKey: "master_volume") }
    }
    
    init() {
        // Set defaults if not set
        if musicVolume == 0 { musicVolume = 0.8 }
        if soundEffectsVolume == 0 { soundEffectsVolume = 0.7 }
        if masterVolume == 0 { masterVolume = 1.0 }
    }
}