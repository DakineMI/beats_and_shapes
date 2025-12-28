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

// MARK: - Beat Manager
class BeatManager {
    let bpm: Double; private var startTime: TimeInterval = 0; private var lastBeatIndex: Int = -1; var onBeat: ((Int) -> Void)?
    init(bpm: Double) { self.bpm = bpm }
    func start() { startTime = CACurrentMediaTime() }
    func update() {
        let elapsedTime = CACurrentMediaTime() - startTime
        let currentBeatIndex = Int(elapsedTime / (60.0 / bpm))
        if currentBeatIndex > lastBeatIndex { lastBeatIndex = currentBeatIndex; onBeat?(currentBeatIndex) }
    }
}

// MARK: - Procedural Rhythm Engine
class RhythmEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isPlaying = false
    private let bpm: Double
    
    init(bpm: Double) {
        self.bpm = bpm
        setupEngine()
    }
    
    private func setupEngine() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }
    
    func playPulse() {
        let sampleRate: Double = 44100
        let duration: Double = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let pcmFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        let channels = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let freq = 60.0 * exp(-20.0 * t)
            channels[i] = Float(sin(2.0 * .pi * freq * t) * exp(-10.0 * t))
        }
        
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !isPlaying { player.play(); isPlaying = true }
    }
    
    func stop() {
        player.stop()
        engine.stop()
    }
}

// MARK: - Scrolling Background
class ScrollingBackground: SKNode {
    private var gridNodes: [SKShapeNode] = []
    private let moveSpeed: CGFloat = 300
    private let spacing: CGFloat = 100
    
    init(size: CGSize) {
        super.init()
        for i in 0...Int(size.width / spacing) + 2 {
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: size.height))
            line.fillColor = .white; line.strokeColor = .clear; line.alpha = 0.1
            line.position = CGPoint(x: CGFloat(i) * spacing, y: size.height / 2)
            addChild(line); gridNodes.append(line)
        }
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }
    
    func update(dt: TimeInterval, size: CGSize) {
        let dx = moveSpeed * CGFloat(dt)
        for line in gridNodes {
            line.position.x -= dx
            if line.position.x < -spacing { line.position.x += size.width + spacing * 2 }
        }
    }
}

// MARK: - Boss Node
class BossNode: SKShapeNode {
    private let core: SKShapeNode
    var hp: Int = 100
    
    init(size: CGFloat = 100) {
        core = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 10)
        super.init()
        core.fillColor = .red; core.strokeColor = .white; core.lineWidth = 4
        addChild(core)
        let p = SKAction.repeatForever(SKAction.sequence([SKAction.scale(to: 1.1, duration: 0.2), SKAction.scale(to: 1.0, duration: 0.2)]))
        core.run(p)
        self.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size, height: size))
        self.physicsBody?.isDynamic = false; self.physicsBody?.categoryBitMask = 0x1 << 1
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }
    
    func attack(scene: SKScene, color: SKColor, phase: Int) {
        if phase % 2 == 0 {
            for i in 0..<12 {
                let angle = CGFloat(i) * (.pi / 6)
                let b = SKShapeNode(circleOfRadius: 15); b.fillColor = color; b.position = self.position
                b.physicsBody = SKPhysicsBody(circleOfRadius: 15); b.physicsBody?.categoryBitMask = 0x1 << 1; b.physicsBody?.collisionBitMask = 0; scene.addChild(b)
                b.run(SKAction.sequence([SKAction.moveBy(x: cos(angle)*1200, y: sin(angle)*1200, duration: 1.5), SKAction.removeFromParent()]))
            }
        } else {
            let b = SKShapeNode(rectOf: CGSize(width: 40, height: 2000))
            b.fillColor = color.withAlphaComponent(0.3); b.position = CGPoint(x: self.position.x - 500, y: self.position.y)
            scene.addChild(b)
            b.run(SKAction.sequence([SKAction.wait(forDuration: 0.4), SKAction.run { b.fillColor = color; b.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 2000)); b.physicsBody?.categoryBitMask = 0x1 << 1 }, SKAction.wait(forDuration: 0.2), SKAction.removeFromParent()]))
        }
    }
}

// MARK: - Player Node
class PlayerNode: SKShapeNode {
    private(set) var isDashing: Bool = false
    var health: Int = 3; private let dashDuration: TimeInterval = 0.1; private let dashCooldown: TimeInterval = 0.2; private var canDash: Bool = true; private var invincible: Bool = false
    init(size: CGFloat = 20) {
        super.init(); let rect = CGRect(x: -size/2, y: -size/2, width: size, height: size); self.path = CGPath(rect: rect, transform: nil); self.fillColor = .cyan; self.strokeColor = .white; self.lineWidth = 2; setupPhysics()
    }
    required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    private func setupPhysics() {
        self.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 14, height: 14)); self.physicsBody?.isDynamic = true; self.physicsBody?.affectedByGravity = false; self.physicsBody?.categoryBitMask = 0x1 << 0; self.physicsBody?.contactTestBitMask = 0x1 << 1 | 0x1 << 2; self.physicsBody?.collisionBitMask = 0
    }
    func updatePos(to position: CGPoint) { if !isDashing { self.position = position } }
    func pulse() { self.run(SKAction.sequence([SKAction.scale(to: 1.2, duration: 0.05), SKAction.scale(to: 1.0, duration: 0.1)])) }
    func dash(direction: CGVector) {
        guard canDash else { return }; isDashing = true; canDash = false; let target = CGPoint(x: position.x + direction.dx * 180, y: position.y + direction.dy * 180)
        self.run(SKAction.move(to: target, duration: dashDuration)) { self.isDashing = false; DispatchQueue.main.asyncAfter(deadline: .now() + self.dashCooldown) { self.canDash = true } }
        for i in 1...4 {
            let g = SKShapeNode(path: self.path!); g.position = self.position; g.strokeColor = .cyan; g.alpha = 0.5 / CGFloat(i); parent?.addChild(g); g.run(SKAction.sequence([SKAction.wait(forDuration: Double(i) * 0.02), SKAction.fadeOut(withDuration: 0.1), SKAction.removeFromParent()]))
        }
    }
    func takeDamage() {
        guard !isDashing && !invincible else { return }; health -= 1; invincible = true
        if let scene = scene as? GameScene { scene.shakeCamera(intensity: 20); scene.updateHealthUI(); if health <= 0 { scene.triggerGameOver() } }
        let f = SKAction.repeat(SKAction.sequence([SKAction.fadeAlpha(to: 0.2, duration: 0.05), SKAction.fadeAlpha(to: 1.0, duration: 0.05)]), count: 15)
        self.run(f) { self.invincible = false }
    }
    func reset() { health = 3; invincible = false; self.alpha = 1.0; self.isHidden = false; self.setScale(1.0) }
}

// MARK: - Obstacle Manager
class ObstacleManager {
    weak var scene: SKScene?
    var currentThemeColor: SKColor = SKColor(red: 1.0, green: 0.1, blue: 0.5, alpha: 1.0)
    init(scene: SKScene) { self.scene = scene }
    func spawnPowerUp(at position: CGPoint) {
        guard let scene = scene else { return }; let p = SKShapeNode(circleOfRadius: 15); p.fillColor = .cyan; p.strokeColor = .white; p.lineWidth = 2; p.position = position; p.name = "powerup"
        p.physicsBody = SKPhysicsBody(circleOfRadius: 15); p.physicsBody?.isDynamic = false; p.physicsBody?.categoryBitMask = 0x1 << 2; p.physicsBody?.contactTestBitMask = 0x1 << 0; scene.addChild(p)
        p.run(SKAction.sequence([SKAction.wait(forDuration: 6.0), SKAction.fadeOut(withDuration: 1.0), SKAction.removeFromParent()]))
    }
    func spawnBeam(at position: CGPoint, horizontal: Bool, speedScale: CGFloat) {
        guard let scene = scene else { return }; let size = horizontal ? CGSize(width: 4000, height: 30) : CGSize(width: 30, height: 4000)
        let beam = SKShapeNode(rectOf: size); beam.fillColor = currentThemeColor.withAlphaComponent(0.2); beam.strokeColor = .clear; beam.position = position; beam.zPosition = -1; scene.addChild(beam)
        let warnTime = max(0.15, 0.4 / speedScale); let pulse = SKAction.repeat(SKAction.sequence([SKAction.fadeAlpha(to: 0.5, duration: warnTime/4), SKAction.fadeAlpha(to: 0.2, duration: warnTime/4)]), count: 2)
        let blast = SKAction.run { beam.fillColor = self.currentThemeColor; beam.physicsBody = SKPhysicsBody(rectangleOf: size); beam.physicsBody?.isDynamic = false; beam.physicsBody?.categoryBitMask = 0x1 << 1 }
        beam.run(SKAction.sequence([pulse, blast, SKAction.wait(forDuration: 0.15), SKAction.fadeOut(withDuration: 0.1), SKAction.removeFromParent()]))
    }
    func spawnAimedShot(from pos: CGPoint, target: CGPoint, speedScale: CGFloat) {
        guard let scene = scene else { return }; let shot = SKShapeNode(rectOf: CGSize(width: 25, height: 25)); shot.fillColor = currentThemeColor; shot.strokeColor = .white; shot.position = pos
        shot.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 25, height: 25)); shot.physicsBody?.isDynamic = false; shot.physicsBody?.categoryBitMask = 0x1 << 1; scene.addChild(shot)
        let dx = target.x - pos.x, dy = target.y - pos.y, dist = sqrt(dx*dx + dy*dy); let duration = max(0.8, 2.5 / speedScale); let move = SKAction.moveBy(x: (dx/dist)*2000, y: (dy/dist)*2000, duration: TimeInterval(duration))
        shot.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi, duration: 0.5))); shot.run(SKAction.sequence([move, SKAction.removeFromParent()]))
    }
    func spawnPulsar(at pos: CGPoint, speedScale: CGFloat) {
        guard let scene = scene else { return }; let p = SKShapeNode(circleOfRadius: 10); p.fillColor = currentThemeColor.withAlphaComponent(0.3); p.position = pos; scene.addChild(p)
        let warnTime = max(0.2, 0.5 / speedScale); let grow = SKAction.scale(to: 15.0, duration: TimeInterval(warnTime))
        let blast = SKAction.run { p.fillColor = self.currentThemeColor; p.alpha = 1.0; let dNode = SKNode(); dNode.physicsBody = SKPhysicsBody(circleOfRadius: 150); dNode.physicsBody?.categoryBitMask = 0x1 << 1; p.addChild(dNode) }
        p.run(SKAction.sequence([grow, blast, SKAction.wait(forDuration: 0.1), SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
    }
}

// MARK: - Game Data
struct Song {
    let id: String; let name: String; let bpm: Double; let totalBeats: Int; let difficultyLabel: String
}
class GameData {
    static let songs = [
        Song(id: "start", name: "THE BEGINNING", bpm: 124, totalBeats: 256, difficultyLabel: "EASY"),
        Song(id: "pulse", name: "NEON PULSE", bpm: 140, totalBeats: 512, difficultyLabel: "NORMAL"),
        Song(id: "stake", name: "THE STAKE", bpm: 160, totalBeats: 1024, difficultyLabel: "HARD"),
        Song(id: "glitch", name: "GLITCH CORE", bpm: 175, totalBeats: 512, difficultyLabel: "EXPERT"),
        Song(id: "void", name: "VOID WALKER", bpm: 110, totalBeats: 2048, difficultyLabel: "MARATHON")
    ]
}

// MARK: - Score Manager
class ScoreManager {
    static func getHighScore(for songId: String) -> Int { UserDefaults.standard.integer(forKey: "high_score_\(songId)") }
    static func saveScore(_ score: Int, for songId: String) {
        let current = getHighScore(for: songId)
        if score > current { UserDefaults.standard.set(score, forKey: "high_score_\(songId)") }
    }
}

// MARK: - Theme
struct Theme {
    let playerColor: SKColor; let obstacleColor: SKColor
    static let themes: [Theme] = [
        Theme(playerColor: .cyan, obstacleColor: SKColor(red: 1.0, green: 0.1, blue: 0.5, alpha: 1.0)),
        Theme(playerColor: .purple, obstacleColor: .yellow),
        Theme(playerColor: .white, obstacleColor: .green)
    ]
}

// MARK: - Splash Screen Scene
class SplashScreenScene: SKScene {
    var onFinished: (() -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var videoPlayer: AVPlayer?
    private var videoLayer: AVPlayerLayer?
    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        if let videoURL = Bundle.main.url(forResource: "splash", withExtension: "mp4") { playVideo(url: videoURL) } else { runSplashSequence() }
    }
    private func playVideo(url: URL) {
        videoPlayer = AVPlayer(url: url); videoLayer = AVPlayerLayer(player: videoPlayer)
        videoLayer?.frame = self.view?.bounds ?? .zero; videoLayer?.videoGravity = .resizeAspectFill
        if let layer = videoLayer { self.view?.layer?.addSublayer(layer) }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: videoPlayer?.currentItem, queue: .main) { [weak self] _ in self?.finish() }
        videoPlayer?.play()
    }
    private func finish() { videoLayer?.removeFromSuperlayer(); self.onFinished?() }
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { skip() }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) { skip() }
    override func keyDown(with event: NSEvent) { skip() }
    #endif
    private func skip() { videoPlayer?.pause(); finish() }
    private func runSplashSequence() {
        let words = ["MAD", "BAD", "BRAX"]; let colors: [SKColor] = [.white, .yellow, .red]
        for (i, word) in words.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = word; label.fontSize = 140; label.fontColor = colors[i]; label.position = CGPoint(x: frame.midX + CGFloat(i - 1) * 280, y: frame.midY + 80); label.setScale(8.0); label.alpha = 0; addChild(label)
            let d = SKAction.wait(forDuration: 0.5 + Double(i) * 0.7); let s = SKAction.group([SKAction.fadeIn(withDuration: 0.05), SKAction.scale(to: 1.0, duration: 0.1), SKAction.run { self.speak(word) }])
            label.run(SKAction.sequence([d, s]))
        }
        let g = SKLabelNode(fontNamed: "AvenirNext-Bold"); g.text = "GAMES"; g.fontSize = 40; g.fontColor = .cyan; g.position = CGPoint(x: frame.midX, y: frame.midY - 40); g.alpha = 0; addChild(g)
        g.run(SKAction.sequence([SKAction.wait(forDuration: 2.5), SKAction.fadeIn(withDuration: 0.3), SKAction.run { self.speak("Games") }, SKAction.wait(forDuration: 2.5), SKAction.run { self.finish() }]))
    }
    private func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text); u.voice = AVSpeechSynthesisVoice(language: "en-US"); u.pitchMultiplier = 0.5; u.rate = 0.4; synthesizer.speak(u)
    }
}

// MARK: - Menu Scene
class MenuScene: SKScene {
    var onSongSelected: ((Song) -> Void)?
    override func didMove(to view: SKView) {
        self.backgroundColor = .black; let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "BEATS & SHAPES"; title.fontSize = 60; title.position = CGPoint(x: frame.midX, y: frame.height * 0.75); title.fontColor = .cyan; addChild(title)
        for (i, song) in GameData.songs.enumerated() {
            let button = SKShapeNode(rectOf: CGSize(width: 450, height: 70), cornerRadius: 10); button.position = CGPoint(x: frame.midX, y: frame.height * 0.5 - CGFloat(i * 90)); button.fillColor = SKColor.white.withAlphaComponent(0.1); button.strokeColor = .cyan; button.name = "song_\(i)"; addChild(button)
            let l = SKLabelNode(fontNamed: "AvenirNext-Bold"); let high = ScoreManager.getHighScore(for: song.id)
            l.text = "\(song.name) (\(song.difficultyLabel)) - HI: \(high)"; l.fontSize = 20; l.position = CGPoint(x: 0, y: -8); l.verticalAlignmentMode = .center; button.addChild(l)
        }
    }
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { if let t = touches.first { h(loc: t.location(in: self)) } }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) { h(loc: event.location(in: self)) }
    #endif
    private func h(loc: CGPoint) { for node in nodes(at: loc) { if let n = node.name, n.hasPrefix("song_") { let i = Int(n.replacingOccurrences(of: "song_", with: "")) ?? 0; onSongSelected?(GameData.songs[i]) } } }
}

// MARK: - Game Scene
class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: PlayerNode!; var beatManager: BeatManager!; var obstacleManager: ObstacleManager!
    var rhythmEngine: RhythmEngine?; var bg: ScrollingBackground?; var boss: BossNode?
    var currentSong: Song?; var onExit: (() -> Void)?
    private var activeKeys = Set<String>(); private var bgPulse = SKNode()
    private var progressBar = SKShapeNode(); private var healthNode = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var scoreNode = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var totalBeats = 512; private var currentBeat = 0; private var skillModifier: CGFloat = 1.0; private var lastScaleDownTime: TimeInterval = 0; private var flawlessBeats = 0; private var isGameOver = false
    private let gameCamera = SKCameraNode(); private var lastUpdateTime: TimeInterval = 0; private var currentScore: Int = 0
    #if os(iOS)
    private var moveTouch: UITouch?; private var joystickCenter: CGPoint?; private var moveVector = CGVector.zero; private let stickBase = SKShapeNode(circleOfRadius: 60); private let stickKnob = SKShapeNode(circleOfRadius: 30)
    #endif
    override func didMove(to view: SKView) {
        let song = currentSong ?? GameData.songs[0]; self.totalBeats = song.totalBeats; self.beatManager = BeatManager(bpm: song.bpm); self.rhythmEngine = RhythmEngine(bpm: song.bpm)
        self.backgroundColor = .black; self.physicsWorld.contactDelegate = self; bg = ScrollingBackground(size: self.size); addChild(bg!)
        self.camera = gameCamera; gameCamera.position = CGPoint(x: frame.midX, y: frame.midY); addChild(gameCamera); addChild(bgPulse)
        #if os(iOS)
        stickBase.strokeColor = .white.withAlphaComponent(0.2); stickBase.lineWidth = 2; stickBase.isHidden = true; addChild(stickBase)
        stickKnob.fillColor = .white.withAlphaComponent(0.3); stickKnob.strokeColor = .white.withAlphaComponent(0.5); stickKnob.lineWidth = 1; stickKnob.isHidden = true; addChild(stickKnob)
        #endif
        player = PlayerNode(); player.position = CGPoint(x: 200, y: frame.midY); addChild(player); setupUI(); obstacleManager = ObstacleManager(scene: self)
        beatManager.onBeat = { [weak self] index in self?.handleBeat(index) }; beatManager.start()
    }
    private func setupUI() {
        progressBar = SKShapeNode(rectOf: CGSize(width: frame.width, height: 6)); progressBar.fillColor = .cyan; progressBar.position = CGPoint(x: 0, y: frame.height/2 - 3); progressBar.xScale = 0; gameCamera.addChild(progressBar)
        healthNode.fontSize = 20; healthNode.fontColor = .white; healthNode.position = CGPoint(x: -frame.width/2 + 80, y: frame.height/2 - 50); healthNode.text = "HEALTH: 3"; gameCamera.addChild(healthNode)
        scoreNode.fontSize = 20; scoreNode.fontColor = .white; scoreNode.position = CGPoint(x: frame.width/2 - 100, y: frame.height/2 - 50); scoreNode.text = "SCORE: 0"; gameCamera.addChild(scoreNode)
    }
    func updateHealthUI() { healthNode.text = "HEALTH: \(player.health)" }
    func shakeCamera(intensity: CGFloat = 12) { 
        gameCamera.run(SKAction.sequence([SKAction.moveBy(x: intensity, y: intensity, duration: 0.04), SKAction.moveBy(x: -intensity*2, y: -intensity*2, duration: 0.04), SKAction.move(to: CGPoint(x: frame.midX, y: frame.midY), duration: 0.04)]))
        let now = CACurrentMediaTime(); if now - lastScaleDownTime > 4.8 { skillModifier = max(skillModifier - 0.02, 0.4); lastScaleDownTime = now }
        flawlessBeats = 0
    }
    func triggerGameOver() { isGameOver = true; if let s = currentSong { ScoreManager.saveScore(currentScore, for: s.id) }; let l = SKLabelNode(fontNamed: "AvenirNext-Heavy"); l.text = "IT'S OVER"; l.fontSize = 80; l.fontColor = .red; l.position = .zero; l.zPosition = 100; gameCamera.addChild(l); l.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.run { self.onExit?() }])) }
    private func handleBeat(_ index: Int) {
        if isGameOver { return }; currentBeat = index; player.pulse(); rhythmEngine?.playPulse(); progressBar.xScale = min(CGFloat(index) / CGFloat(totalBeats), 1.0)
        let theme = Theme.themes[(currentBeat / 64) % Theme.themes.count]; player.fillColor = theme.playerColor; obstacleManager.currentThemeColor = theme.obstacleColor
        currentScore += 10; scoreNode.text = "SCORE: \(currentScore)"
        let flash = SKShapeNode(rect: frame); flash.position = CGPoint(x: -frame.midX, y: -frame.midY); flash.fillColor = .white; flash.alpha = 0.05; bgPulse.addChild(flash); flash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.1), SKAction.removeFromParent()]))
        flawlessBeats += 1; let comb = skillModifier
        if index > totalBeats - 64 && boss == nil { boss = BossNode(); boss?.position = CGPoint(x: frame.width - 200, y: frame.midY); addChild(boss!) }
        if let b = boss { b.attack(scene: self, color: theme.obstacleColor, phase: index / 8) } else {
            if index % Int(max(1, 16/comb)) == 0 { let isH = Bool.random(); obstacleManager.spawnBeam(at: isH ? CGPoint(x: frame.midX, y: CGFloat.random(in: 100...frame.height-100)) : CGPoint(x: CGFloat.random(in: 100...frame.width-100), y: frame.midY), horizontal: isH, speedScale: comb) }
            if index % Int(max(1, 12/comb)) == 0 { obstacleManager.spawnAimedShot(from: CGPoint(x: frame.width, y: CGFloat.random(in: 0...frame.height)), target: player.position, speedScale: comb) }
            if index % Int(max(1, 24/comb)) == 0 { obstacleManager.spawnPulsar(at: CGPoint(x: CGFloat.random(in: 200...frame.width-200), y: CGFloat.random(in: 200...frame.height-200)), speedScale: comb) }
        }
    }
    override func update(_ currentTime: TimeInterval) {
        if isGameOver { return }; if lastUpdateTime == 0 { lastUpdateTime = currentTime }; let dt = currentTime - lastUpdateTime; lastUpdateTime = currentTime
        bg?.update(dt: dt, size: self.size); beatManager.update(); #if os(macOS)
        updateKbdMove(); #elseif os(iOS)
        updateJoystick(); #endif
        let ps = CGFloat(15); player.position.x = max(ps, min(frame.width - ps, player.position.x)); player.position.y = max(ps, min(frame.height - ps, player.position.y))
        if currentBeat >= totalBeats && !isGameOver { isGameOver = true; if let s = currentSong { ScoreManager.saveScore(currentScore, for: s.id) }; let l = SKLabelNode(fontNamed: "AvenirNext-Heavy"); l.text = "WIN"; l.fontSize = 80; l.fontColor = .cyan; l.position = .zero; l.zPosition = 100; gameCamera.addChild(l); l.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.run { self.onExit?() }])) }
    }
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { for t in touches { let loc = t.location(in: self); if loc.x < frame.width / 2 { if moveTouch == nil { moveTouch = t; joystickCenter = loc; stickBase.position = loc; stickBase.isHidden = false; stickKnob.position = loc; stickKnob.isHidden = false } } else { player.dash(direction: moveVector == .zero ? CGVector(dx: 1, dy: 0) : moveVector) } } }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { if let t = moveTouch, let c = joystickCenter { let loc = t.location(in: self); let dx = loc.x - c.x, dy = loc.y - c.y, d = sqrt(dx*dx + dy*dy); if d > 4 { let maxD: CGFloat = 80.0, intensity = min(d / maxD, 1.0); moveVector = CGVector(dx: (dx/d)*intensity, dy: (dy/d)*intensity); stickKnob.position = CGPoint(x: c.x + (dx/d)*min(d, maxD), y: c.y + (dy/d)*min(d, maxD)) } else { moveVector = .zero; stickKnob.position = c } } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { for t in touches { if t == moveTouch { moveTouch = nil; moveVector = .zero; stickBase.isHidden = true; stickKnob.isHidden = true } } }
    private func updateJoystick() { if moveVector != .zero { player.updatePos(to: CGPoint(x: player.position.x + moveVector.dx*15, y: player.position.y + moveVector.dy*15)) } }
    #elseif os(macOS)
    override func keyDown(with event: NSEvent) { if let chars = event.charactersIgnoringModifiers { activeKeys.insert(chars.lowercased()) }; if event.keyCode == 49 { dashK() } }
    override func keyUp(with event: NSEvent) { if let chars = event.charactersIgnoringModifiers { activeKeys.remove(chars.lowercased()) } }
    private var kbdInt: CGFloat = 0.0
    private func updateKbdMove() { var dx: CGFloat = 0, dy: CGFloat = 0; if activeKeys.contains("w") { dy += 1 }; if activeKeys.contains("s") { dy -= 1 }; if activeKeys.contains("a") { dx -= 1 }; if activeKeys.contains("d") { dx += 1 }
        if dx != 0 || dy != 0 { kbdInt = min(kbdInt + 0.05, 1.0); let len = sqrt(dx*dx + dy*dy); player.updatePos(to: CGPoint(x: player.position.x + (dx/len)*16*kbdInt, y: player.position.y + (dy/len)*16*kbdInt)) } else { kbdInt = max(kbdInt - 0.1, 0.0) } }
    private func dashK() { var dx: CGFloat = 0, dy: CGFloat = 0; if activeKeys.contains("w") { dy += 1 }; if activeKeys.contains("s") { dy -= 1 }; if activeKeys.contains("a") { dx -= 1 }; if activeKeys.contains("d") { dx += 1 }
        if dx == 0 && dy == 0 { dx = 1 }; let len = sqrt(dx*dx + dy*dy); player.dash(direction: CGVector(dx: dx/len, dy: dy/len)) }
    #endif
    func didBegin(_ contact: SKPhysicsContact) { let c = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if c == (0x1 << 0 | 0x1 << 1) { player.takeDamage() }
        if c == (0x1 << 0 | 0x1 << 2) { let p = (contact.bodyA.categoryBitMask == 0x1 << 2) ? contact.bodyA.node : contact.bodyB.node; p?.removeFromParent(); player.health = min(player.health + 1, 3); updateHealthUI() } }
}

// MARK: - App Entry
#if os(iOS)
struct SpriteKitContainer: UIViewRepresentable {
    let scene: SKScene
    func makeUIView(context: Context) -> SKView { let v = SKView(); v.preferredFramesPerSecond = 120; v.presentScene(scene); return v }
    func updateUIView(_ uiView: SKView, context: Context) { if uiView.scene != scene { uiView.presentScene(scene) } }
}
#elseif os(macOS)
struct SpriteKitContainer: NSViewRepresentable {
    let scene: SKScene
    func makeNSView(context: Context) -> SKView { let v = SKView(); v.preferredFramesPerSecond = 120; v.presentScene(scene); return v }
    func updateNSView(_ nsView: SKView, context: Context) { if nsView.scene != scene { nsView.presentScene(scene) } }
}
#endif
struct ContentView: View {
    @State private var currentScene: SKScene?
    var body: some View { ZStack { if let s = currentScene { SpriteKitContainer(scene: s).ignoresSafeArea() } }.background(Color.black).onAppear { showSplash() } }
    func showSplash() { let s = SplashScreenScene(); s.size = CGSize(width: 1024, height: 768); s.scaleMode = .aspectFill; s.onFinished = { showMenu() }; currentScene = s }
    func showMenu() { let m = MenuScene(); m.size = CGSize(width: 1024, height: 768); m.scaleMode = .aspectFill; m.onSongSelected = { startGame(with: $0) }; currentScene = m }
    func startGame(with s: Song) { let g = GameScene(); g.size = CGSize(width: 1024, height: 768); g.scaleMode = .aspectFill; g.currentSong = s; g.onExit = { showMenu() }; currentScene = g }
}
@main
struct BeatsAndShapesApp: App {
    var body: some Scene { WindowGroup { ContentView() }
    #if os(macOS)
    .windowStyle(.hiddenTitleBar)
    #endif
    }
}
