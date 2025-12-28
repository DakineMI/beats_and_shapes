import SwiftUI
import SpriteKit
import Foundation

/// Modern SwiftUI-based game view using proper MVVM architecture
struct GameView: View {
    @StateObject private var sceneManager = GameSceneManager()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some View {
        NavigationStack(path: $sceneManager.navigationPath) {
            VStack {
                if let scene = sceneManager.currentScene {
                    SpriteKitContainer(scene: scene)
                        .ignoresSafeArea()
                        .onAppear {
                            setupWindow()
                            sceneManager.showSplash {
                                sceneManager.showMenu()
                            }
                        }
                }
            }
            .navigationDestination(for: GameState.self) { state in
                gameStateView(for: state)
            }
        }
        .environmentObject(sceneManager)
        .environmentObject(settingsManager)
        .background(.black)
    }
    
    @ViewBuilder
    private func gameStateView(for state: GameState) -> some View {
        switch state {
        case .settings:
            SettingsView()
        default:
            EmptyView()
        }
    }
    
    private func setupWindow() {
        #if os(macOS)
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
        #endif
    }
}

/// Modern game scene with proper separation of concerns
class ModernGameScene: SKScene {
    // MARK: - Dependencies
    @Injected(\.audioEngine) private var audioEngine
    @Injected(\.scoringSystem) private var scoringSystem
    @Injected(\.beatManager) private var beatManager
    @Injected(\.settingsManager) private var settingsManager
    
    // MARK: - Game Components
    private var player: PlayerNode?
    private var background: ScrollingBackground?
    private var boss: BossNode?
    
    // MARK: - Game State
    private var currentSong: Song
    private var currentBeat = 0
    private var isGameOver = false
    private var lastTime: TimeInterval = 0
    
    // MARK: - UI Components
    private var hudController: HUDController?
    private var inputController: InputController?
    
    // MARK: - Callbacks
    var onGameEnded: ((Int) -> Void)?
    
    init(song: Song) {
        self.currentSong = song
        super.init()
        setupDependencies()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        setupScene()
        setupGameComponents()
        setupUI()
        setupInputHandling()
    }
    
    private func setupDependencies() {
        beatManager = BeatManager(bpm: currentSong.bpm)
    }
    
    private func setupScene() {
        physicsWorld.contactDelegate = self
        backgroundColor = GameConstants.Colors.background
        
        // Setup camera
        let camera = SKCameraNode()
        camera.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(camera)
        self.camera = camera
    }
    
    private func setupGameComponents() {
        // Player
        player = PlayerNode()
        player?.position = CGPoint(x: 200, y: frame.midY)
        if let player = player {
            addChild(player)
        }
        
        // Background
        background = ScrollingBackground(size: size)
        if let background = background {
            addChild(background)
        }
        
        // Audio engine
        audioEngine.playPulse(beatIndex: 0)
        
        // Beat manager
        beatManager?.onBeat = { [weak self] beatIndex in
            self?.handleBeat(beatIndex)
        }
        beatManager?.start()
    }
    
    private func setupUI() {
        hudController = HUDController(camera: camera!, scene: self)
        hudController?.setup()
    }
    
    private func setupInputHandling() {
        inputController = InputController(scene: self, player: player)
        inputController?.setup()
    }
    
    private func handleBeat(_ index: Int) {
        guard !isGameOver else { return }
        
        currentBeat = index
        
        // Update player pulse
        player?.pulse()
        
        // Play audio
        audioEngine.playPulse(beatIndex: index)
        
        // Update scoring
        scoringSystem.registerHit(quality: .perfect) // Simplified for now
        hudController?.updateScore(scoringSystem.score)
        
        // Generate obstacles based on beat state
        generateObstacles(for: index)
        
        // Handle boss battle
        handleBossBattle(at: index)
        
        // Check for level completion
        checkLevelCompletion()
    }
    
    private func generateObstacles(for beatIndex: Int) {
        let beatState = audioEngine.getBeatState(index: beatIndex)
        let obstacleGenerator = ObstacleGenerator()
        
        obstacleGenerator.generateObstacles(
            beatState: beatState,
            beatIndex: beatIndex,
            in: self
        )
    }
    
    private func handleBossBattle(at beatIndex: Int) {
        if beatIndex > currentSong.totalBeats - GameConstants.bossAppearBeatsRemaining {
            spawnBossIfNeeded()
            
            if let boss = boss {
                boss.attack(
                    scene: self,
                    color: GameConstants.Colors.obstacle,
                    phase: beatIndex / 8,
                    beatInPhase: beatIndex % 8
                )
            }
        }
    }
    
    private func spawnBossIfNeeded() {
        guard boss == nil else { return }
        
        boss = BossNode(size: GameConstants.bossSize)
        boss?.position = CGPoint(x: frame.width - 200, y: frame.midY)
        
        if let boss = boss {
            addChild(boss)
        }
    }
    
    private func checkLevelCompletion() {
        guard currentBeat >= currentSong.totalBeats else { return }
        
        endGame()
    }
    
    private func endGame() {
        isGameOver = true
        audioEngine.stop()
        
        let finalScore = scoringSystem.score
        onGameEnded?(finalScore)
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
        let deltaTime = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime
        
        // Update components
        background?.update(dt: deltaTime, size: size)
        beatManager?.update()
        scoringSystem.update()
        
        // Update player boundaries
        updatePlayerBoundaries()
    }
    
    private func updatePlayerBoundaries() {
        guard let player = player else { return }
        
        let minX: CGFloat = 20
        let maxX = frame.width - 20
        let minY: CGFloat = 20
        let maxY = frame.height - 20
        
        player.position.x = max(minX, min(maxX, player.position.x))
        player.position.y = max(minY, min(maxY, player.position.y))
    }
}

// MARK: - Modern UI Controllers
class HUDController {
    private weak var camera: SKCameraNode?
    private weak var scene: SKScene?
    
    private var healthLabel: SKLabelNode?
    private var scoreLabel: SKLabelNode?
    private var comboLabel: SKLabelNode?
    
    init(camera: SKCameraNode, scene: SKScene) {
        self.camera = camera
        self.scene = scene
    }
    
    func setup() {
        guard let camera = camera, let scene = scene else { return }
        
        // Health label
        healthLabel = SKLabelNode(fontNamed: GameConstants.Fonts.bold)
        healthLabel?.text = "HP: 3"
        healthLabel?.fontSize = 18
        healthLabel?.fontColor = GameConstants.Colors.health
        healthLabel?.position = CGPoint(x: -scene.frame.width/2 + 80, y: scene.frame.height/2 - 50)
        camera.addChild(healthLabel!)
        
        // Score label
        scoreLabel = SKLabelNode(fontNamed: GameConstants.Fonts.bold)
        scoreLabel?.text = "SCORE: 0"
        scoreLabel?.fontSize = 18
        scoreLabel?.fontColor = GameConstants.Colors.text
        scoreLabel?.position = CGPoint(x: scene.frame.width/2 - 80, y: scene.frame.height/2 - 50)
        camera.addChild(scoreLabel!)
        
        // Combo label
        comboLabel = SKLabelNode(fontNamed: GameConstants.Fonts.bold)
        comboLabel?.text = ""
        comboLabel?.fontSize = 24
        comboLabel?.fontColor = GameConstants.Colors.player
        comboLabel?.position = CGPoint(x: 0, y: scene.frame.height/2 - 100)
        camera.addChild(comboLabel!)
    }
    
    func updateScore(_ score: Int) {
        scoreLabel?.text = "SCORE: \(score)"
    }
    
    func updateHealth(_ health: Int) {
        healthLabel?.text = "HP: \(health)"
    }
    
    func updateCombo(_ combo: Int) {
        if combo > 1 {
            comboLabel?.text = "\(combo)x COMBO!"
            comboLabel?.run(SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ]))
        } else {
            comboLabel?.text = ""
        }
}

class InputController {
    private weak var scene: SKScene?
    private weak var player: PlayerNode?
    
    init(scene: SKScene, player: PlayerNode?) {
        self.scene = scene
        self.player = player
    }
    
    func setup() {
        #if os(macOS)
        setupKeyboardControls()
        #endif
    }
    
    #if os(macOS)
    private func setupKeyboardControls() {
        scene?.keyDownHandler = { [weak self] event in
            self?.handleKeyPress(event)
        }
    }
    
    private func handleKeyPress(_ event: NSEvent) {
        guard let player = player else { return }
        
        switch event.keyCode {
        case 53: // ESC
            scene?.view?.isPaused = true
        case 123: // Left arrow
            player.position.x -= 20
        case 124: // Right arrow
            player.position.x += 20
        case 125: // Down arrow
            player.position.y -= 20
        case 126: // Up arrow
            player.position.y += 20
        case 49: // Space
            player.dash(direction: CGVector(dx: 1, dy: 0))
        default:
            break
        }
    }
    #endif
}
}