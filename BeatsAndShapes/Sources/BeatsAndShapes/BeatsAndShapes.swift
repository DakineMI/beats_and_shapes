import SwiftUI
import SpriteKit
import QuartzCore
import AVFoundation
import AVKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Progress Manager
class ProgressManager {
    static let highestUnlockedKey = "highest_unlocked_level"
    static func getHighestUnlocked() -> Int { UserDefaults.standard.integer(forKey: highestUnlockedKey) }
    static func unlockNext(current: Int) {
        let highest = getHighestUnlocked()
        if current >= highest { UserDefaults.standard.set(current + 1, forKey: highestUnlockedKey) }
    }
    static func getHighScore(for songId: String) -> Int { UserDefaults.standard.integer(forKey: "high_score_\(songId)") }
    static func saveScore(_ score: Int, for songId: String) {
        let current = getHighScore(for: songId)
        if score > current { UserDefaults.standard.set(score, forKey: "high_score_\(songId)") }
    }
}

// MARK: - Beat Manager
class BeatManager {
    let bpm: Double
    private var startTime: TimeInterval = 0
    private var lastBeatIndex: Int = -1
    var onBeat: ((Int) -> Void)?
    
    init(bpm: Double) { self.bpm = bpm }
    func start() { startTime = CACurrentMediaTime(); lastBeatIndex = -1 }
    func update() {
        let elapsedTime = CACurrentMediaTime() - startTime
        let currentBeatIndex = Int(elapsedTime / (60.0 / bpm))
        if currentBeatIndex > lastBeatIndex { 
            lastBeatIndex = currentBeatIndex
            onBeat?(currentBeatIndex) 
        }
    }
}

// MARK: - Audio Engine
typealias RhythmEngine = AudioEngine

// MARK: - Scrolling Background
class ScrollingBackground: SKNode {
    private var gridNodes: [SKShapeNode] = []
    private let moveSpeed: CGFloat = 300; private let spacing: CGFloat = 100
    init(size: CGSize) {
        super.init()
        for i in 0...Int(size.width / spacing) + 2 {
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: size.height))
            line.fillColor = .white; line.alpha = 0.1; line.position = CGPoint(x: CGFloat(i) * spacing, y: size.height / 2); addChild(line); gridNodes.append(line)
        }
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }
    func update(dt: TimeInterval, size: CGSize) {
        let dx = moveSpeed * CGFloat(dt)
        for line in gridNodes { line.position.x -= dx; if line.position.x < -spacing { line.position.x += size.width + spacing * 2 } }
    }
}

// MARK: - Boss Node
class BossNode: SKShapeNode {
    private let core: SKShapeNode; var hp: Int = 100
    init(size: CGFloat = 100) {
        core = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 10); super.init()
        core.fillColor = .red; core.strokeColor = .white; core.lineWidth = 4; addChild(core)
        core.run(SKAction.repeatForever(SKAction.sequence([SKAction.scale(to: 1.1, duration: 0.2), SKAction.scale(to: 1.0, duration: 0.2)])))
        self.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size, height: size)); self.physicsBody?.isDynamic = false; self.physicsBody?.categoryBitMask = 0x1 << 1
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }
    func attack(scene: SKScene, color: SKColor, phase: Int, beatInPhase: Int) {
        if phase % 3 == 0 && beatInPhase == 0 {
            for i in 0..<12 {
                let angle = CGFloat(i) * (.pi / 6); let b = SKShapeNode(circleOfRadius: 15); b.fillColor = color; b.position = self.position
                b.physicsBody = SKPhysicsBody(circleOfRadius: 15); b.physicsBody?.categoryBitMask = 0x1 << 1; scene.addChild(b)
                b.run(SKAction.sequence([SKAction.moveBy(x: cos(angle)*1200, y: sin(angle)*1200, duration: 1.5), SKAction.removeFromParent()]))
            }
        } else if phase % 3 == 1 && beatInPhase == 0 {
            let b = SKShapeNode(rectOf: CGSize(width: 40, height: 2000)); b.fillColor = color.withAlphaComponent(0.3); b.position = CGPoint(x: self.position.x - 500, y: self.position.y); scene.addChild(b)
            b.run(SKAction.sequence([SKAction.wait(forDuration: 0.4), SKAction.run { b.fillColor = color; b.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 2000)); b.physicsBody?.categoryBitMask = 0x1 << 1 }, SKAction.wait(forDuration: 0.2), SKAction.removeFromParent()]))
        } else if phase % 3 == 2 && beatInPhase == 0 {
            let wave = SKShapeNode(circleOfRadius: 10); wave.position = self.position; wave.strokeColor = color; wave.lineWidth = 5; scene.addChild(wave)
            wave.run(SKAction.sequence([SKAction.group([SKAction.scale(to: 50.0, duration: 0.8), SKAction.fadeOut(withDuration: 0.8)]), SKAction.removeFromParent()]))
            let d = SKNode(); d.physicsBody = SKPhysicsBody(circleOfRadius: 500); d.physicsBody?.categoryBitMask = 0x1 << 1; wave.addChild(d)
        }
    }
}

// MARK: - Player Node
class PlayerNode: SKShapeNode {
    private(set) var isDashing: Bool = false; var health: Int = 3; private var invincible: Bool = false
    init(size: CGFloat = 20) {
        super.init(); let rect = CGRect(x: -size/2, y: -size/2, width: size, height: size); self.path = CGPath(rect: rect, transform: nil); self.fillColor = .cyan; self.strokeColor = .white; self.lineWidth = 2
        self.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 14, height: 14)); self.physicsBody?.isDynamic = true; self.physicsBody?.affectedByGravity = false; self.physicsBody?.categoryBitMask = 0x1 << 0; self.physicsBody?.contactTestBitMask = 0x1 << 1; self.physicsBody?.collisionBitMask = 0
    }
    required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    func pulse() { self.run(SKAction.sequence([SKAction.scale(to: 1.2, duration: 0.05), SKAction.scale(to: 1.0, duration: 0.1)])) }
    func dash(direction: CGVector) {
        guard !isDashing else { return }; isDashing = true; let target = CGPoint(x: position.x + direction.dx * 180, y: position.y + direction.dy * 180)
        self.run(SKAction.move(to: target, duration: 0.1)) { self.isDashing = false }
        for i in 1...3 { let g = SKShapeNode(path: self.path!); g.position = self.position; g.strokeColor = .cyan; g.alpha = 0.4; parent?.addChild(g); g.run(SKAction.sequence([SKAction.wait(forDuration: Double(i)*0.03), SKAction.fadeOut(withDuration: 0.1), SKAction.removeFromParent()])) }
    }
    func takeDamage() {
        guard !isDashing && !invincible else { return }; health -= 1; invincible = true
        if let scene = scene as? GameScene { scene.shakeCamera(intensity: 20); scene.updateHealthUI(); if health <= 0 { scene.triggerGameOver() } }
        self.run(SKAction.repeat(SKAction.sequence([SKAction.fadeAlpha(to: 0.2, duration: 0.05), SKAction.fadeAlpha(to: 1.0, duration: 0.05)]), count: 10)) { self.invincible = false }
    }
}

// MARK: - Game Data
struct Song { let id: String; let name: String; let bpm: Double; let totalBeats: Int; let difficulty: String; let volume: Int; let audioFile: String? }
class GameData {
    static let songs: [Song] = (0..<100).map { i in
        let vol = (i / 20) + 1; let bpm = 120.0 + Double(i % 20) * 4.0
        return Song(id: "s\(i)", name: "TRACK \(i+1)", bpm: bpm, totalBeats: 256 + (i*16), difficulty: i < 20 ? "EASY" : i < 60 ? "NORMAL" : "EXPERT", volume: vol, audioFile: nil)
    }
}

// MARK: - Splash Screen Scene
class SplashScreenScene: SKScene {
    var onFinished: (() -> Void)?
    private var videoPlayer: AVPlayer?; private var videoLayer: AVPlayerLayer?
    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        if let url = Bundle.main.url(forResource: "splash", withExtension: "mp4") {
            let p = AVPlayer(url: url); let l = AVPlayerLayer(player: p)
            self.videoPlayer = p; self.videoLayer = l
            l.frame = view.bounds; l.videoGravity = .resizeAspectFill
            if let bl = view.layer { bl.addSublayer(l) }
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { [weak self] _ in self?.finish() }
            p.play()
        } else { runFallback() }
    }
    private func finish() { 
        videoPlayer?.pause()
        videoLayer?.removeFromSuperlayer()
        onFinished?() 
    }
    private func runFallback() {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy"); label.text = "BadMadBrax"; label.fontSize = 80; label.position = CGPoint(x: frame.midX, y: frame.midY); addChild(label)
        label.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.run { self.finish() }]))
    }
    #if os(macOS)
    override func mouseDown(with event: NSEvent) { finish() }
    #endif
}

// MARK: - Menu Scene
class MenuScene: SKScene {
    var onSongSelected: ((Song) -> Void)?
    private var currentVol = 1
    override func didMove(to view: SKView) { self.backgroundColor = .black; setupUI() }
    private func setupUI() {
        removeAllChildren()
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy"); title.text = "VOLUME \(currentVol)"; title.fontSize = 40; title.position = CGPoint(x: frame.midX, y: frame.height * 0.88); addChild(title)
        let songsInVol = GameData.songs.filter { $0.volume == currentVol }; let highest = ProgressManager.getHighestUnlocked()
        for (i, song) in songsInVol.enumerated() {
            let globalIdx = (currentVol - 1) * 20 + i; let isUnlocked = globalIdx <= highest; let col = i % 4; let row = i / 4
            let btn = SKShapeNode(rectOf: CGSize(width: frame.width * 0.22, height: 75), cornerRadius: 8)
            btn.position = CGPoint(x: frame.width * (0.15 + CGFloat(col) * 0.233), y: frame.height * (0.72 - CGFloat(row) * 0.15))
            btn.fillColor = isUnlocked ? .cyan.withAlphaComponent(0.2) : .gray.withAlphaComponent(0.1)
            btn.strokeColor = isUnlocked ? .cyan : .gray; btn.name = "song_\(globalIdx)"; addChild(btn)
            let l = SKLabelNode(fontNamed: "AvenirNext-Bold"); l.fontSize = 14; l.text = isUnlocked ? song.name : "LOCKED"; l.position = CGPoint(x: 0, y: 5); btn.addChild(l)
            if isUnlocked { let s = SKLabelNode(fontNamed: "AvenirNext-Medium"); s.text = "HI: \(ProgressManager.getHighScore(for: song.id))"; s.fontSize = 10; s.position = CGPoint(x: 0, y: -20); btn.addChild(s) }
        }
        if currentVol > 1 { let p = SKLabelNode(text: "< PREV VOL"); p.name = "prev"; p.position = CGPoint(x: 100, y: 50); addChild(p) }
        if currentVol < 5 { let n = SKLabelNode(text: "NEXT VOL >"); n.name = "next"; n.position = CGPoint(x: frame.width - 100, y: 50); addChild(n) }
    }
    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let loc = event.location(in: self); for n in nodes(at: loc) {
            if n.name == "prev" { currentVol -= 1; setupUI() }
            else if n.name == "next" { currentVol += 1; setupUI() }
            else if let name = n.name, name.hasPrefix("song_") {
                let idx = Int(name.replacingOccurrences(of: "song_", with: "")) ?? 0
                if idx <= ProgressManager.getHighestUnlocked() { onSongSelected?(GameData.songs[idx]) }
            }
        }
    }
    #endif
}

// MARK: - Game Scene
class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: PlayerNode!; var beatManager: BeatManager!; var rhythmEngine: RhythmEngine!
    var bg: ScrollingBackground!; var boss: BossNode?; var currentSong: Song!; var onExit: (() -> Void)?
    private var currentBeat = 0; private var score = 0; private var isGameOver = false; private let cam = SKCameraNode()
    private var lastTime: TimeInterval = 0; private let healthL = SKLabelNode(text: ""); private let scoreL = SKLabelNode(text: "")
    private var activeObstaclesCount = 0; private let maxObstacles = 12; private var lastTypeOccurrences: [String: Int] = ["beam": 0, "aimed": 0, "pulsar": 0]
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self; backgroundColor = .black
        beatManager = BeatManager(bpm: currentSong.bpm); rhythmEngine = RhythmEngine(bpm: currentSong.bpm, audioFileName: currentSong.audioFile)
        bg = ScrollingBackground(size: size); addChild(bg)
        camera = cam; cam.position = CGPoint(x: frame.midX, y: frame.midY); addChild(cam)
        player = PlayerNode(); player.position = CGPoint(x: 200, y: frame.midY); addChild(player)
        setupHUD(); beatManager.onBeat = { [weak self] i in self?.handleBeat(i) }; beatManager.start()
    }
    private func setupHUD() {
        healthL.position = CGPoint(x: -frame.width/2 + 80, y: frame.height/2 - 50); cam.addChild(healthL)
        scoreL.position = CGPoint(x: frame.width/2 - 80, y: frame.height/2 - 50); cam.addChild(scoreL); updateHealthUI()
    }
    func updateHealthUI() { healthL.text = "HP: \(player.health)"; scoreL.text = "SCORE: \(score)" }
    func shakeCamera(intensity: CGFloat) { cam.run(SKAction.sequence([SKAction.moveBy(x: intensity, y: intensity, duration: 0.04), SKAction.moveBy(x: -intensity*2, y: -intensity*2, duration: 0.04), SKAction.move(to: CGPoint(x: frame.midX, y: frame.midY), duration: 0.04)])) }
    func triggerGameOver() { isGameOver = true; ProgressManager.saveScore(score, for: currentSong.id); rhythmEngine.stop(); onExit?() }
    private func handleBeat(_ index: Int) {
        if isGameOver { return }; currentBeat = index; player.pulse(); rhythmEngine.playPulse(beatIndex: index); score += 10; updateHealthUI()
        let state = rhythmEngine.getBeatState(index: index)
        if activeObstaclesCount < maxObstacles {
            if state.kick && index % 4 == 0 { spawnBeam(at: CGPoint(x: frame.midX, y: frame.height * CGFloat(drand48())), horizontal: true); lastTypeOccurrences["beam"] = index }
            if state.snare && index % 4 == 2 { spawnBeam(at: CGPoint(x: frame.width * CGFloat(drand48()), y: frame.midY), horizontal: false); lastTypeOccurrences["beam"] = index }
            if state.hornTrigger { spawnPulsar(at: CGPoint(x: frame.midX, y: frame.midY)); lastTypeOccurrences["pulsar"] = index }
            if state.fiddleTrigger { spawnAimedShot(from: CGPoint(x: frame.width, y: frame.height * CGFloat(drand48())), target: player.position); lastTypeOccurrences["aimed"] = index }
        }
        if index - (lastTypeOccurrences["aimed"] ?? 0) > 12 { spawnAimedShot(from: CGPoint(x: frame.width, y: frame.height * 0.5), target: player.position); lastTypeOccurrences["aimed"] = index }
        if index > currentSong.totalBeats - 64 && boss == nil { boss = BossNode(); boss?.position = CGPoint(x: frame.width - 200, y: frame.midY); addChild(boss!) }
        boss?.attack(scene: self, color: .red, phase: index / 8, beatInPhase: index % 8)
    }
    private func spawnBeam(at pos: CGPoint, horizontal: Bool) {
        activeObstaclesCount += 1; let size = horizontal ? CGSize(width: 4000, height: 30) : CGSize(width: 30, height: 4000)
        let b = SKShapeNode(rectOf: size); b.fillColor = .red; b.position = pos; b.physicsBody = SKPhysicsBody(rectangleOf: size); b.physicsBody?.isDynamic = false; b.physicsBody?.categoryBitMask = 0x1 << 1; addChild(b)
        b.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.fadeOut(withDuration: 0.2), SKAction.run { self.activeObstaclesCount -= 1 }, SKAction.removeFromParent()]))
    }
    private func spawnPulsar(at pos: CGPoint) {
        activeObstaclesCount += 1; let p = SKShapeNode(circleOfRadius: 10); p.fillColor = .red; p.position = pos; addChild(p)
        p.run(SKAction.sequence([SKAction.group([SKAction.scale(to: 10.0, duration: 0.4), SKAction.fadeOut(withDuration: 0.4)]), SKAction.run { 
            let d = SKNode(); d.position = pos; d.physicsBody = SKPhysicsBody(circleOfRadius: 100); d.physicsBody?.categoryBitMask = 0x1 << 1; self.addChild(d)
            d.run(SKAction.sequence([SKAction.wait(forDuration: 0.1), SKAction.removeFromParent()])); self.activeObstaclesCount -= 1 
        }, SKAction.removeFromParent()]))
    }
    private func spawnAimedShot(from pos: CGPoint, target: CGPoint) {
        activeObstaclesCount += 1; let s = SKShapeNode(rectOf: CGSize(width: 20, height: 20)); s.fillColor = .red; s.position = pos
        s.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 20)); s.physicsBody?.isDynamic = false; s.physicsBody?.categoryBitMask = 0x1 << 1; addChild(s)
        let dx = target.x - pos.x, dy = target.y - pos.y, dist = sqrt(dx*dx + dy*dy)
        s.run(SKAction.sequence([SKAction.moveBy(x: (dx/dist)*2000, y: (dy/dist)*2000, duration: 2.0), SKAction.run { self.activeObstaclesCount -= 1 }, SKAction.removeFromParent()]))
    }
    override func update(_ currentTime: TimeInterval) {
        if isGameOver { return }; if lastTime == 0 { lastTime = currentTime }; let dt = currentTime - lastTime; lastTime = currentTime
        bg.update(dt: dt, size: size); beatManager.update()
        player.position.x = max(20, min(frame.width - 20, player.position.x)); player.position.y = max(20, min(frame.height - 20, player.position.y))
        if currentBeat >= currentSong.totalBeats { ProgressManager.unlockNext(current: GameData.songs.firstIndex(where: { $0.id == currentSong.id }) ?? 0); triggerWin() }
    }
    private func triggerWin() { isGameOver = true; ProgressManager.saveScore(score, for: currentSong.id); rhythmEngine.stop(); onExit?() }
    #if os(macOS)
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { isGameOver = true; rhythmEngine.stop(); onExit?() } }
    #endif
}

struct SpriteKitContainer: NSViewRepresentable {
    let scene: SKScene
    func makeNSView(context: Context) -> SKView { let v = SKView(); v.preferredFramesPerSecond = 120; v.presentScene(scene); return v }
    func updateNSView(_ nsView: SKView, context: Context) { if nsView.scene != scene { nsView.presentScene(scene) } }
}
struct ContentView: View {
    @State private var currentScene: SKScene?
    var body: some View { ZStack { if let s = currentScene { SpriteKitContainer(scene: s).ignoresSafeArea() } }.background(Color.black).onAppear { 
        #if os(macOS)
        if let w = NSApplication.shared.windows.first { w.toggleFullScreen(nil) }
        #endif
        showSplash() 
    } }
    func showSplash() { let s = SplashScreenScene(); s.size = CGSize(width: 1024, height: 768); s.scaleMode = .aspectFill; s.onFinished = { showMenu() }; currentScene = s }
    func showMenu() { let m = MenuScene(); m.size = CGSize(width: 1024, height: 768); m.scaleMode = .aspectFill; m.onSongSelected = { startGame(with: $0) }; currentScene = m }
    func startGame(with s: Song) { let g = GameScene(); g.size = CGSize(width: 1024, height: 768); g.scaleMode = .aspectFill; g.currentSong = s; g.onExit = { showMenu() }; currentScene = g }
}
@main
struct BeatsAndShapesApp: App { 
    var body: some Scene { 
        WindowGroup { 
            GameView() 
        } 
        .windowStyle(.hiddenTitleBar) 
    } 
}
