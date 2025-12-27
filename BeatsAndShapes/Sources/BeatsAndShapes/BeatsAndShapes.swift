import SwiftUI
import SpriteKit
import QuartzCore
import AVFoundation

#if os(iOS)
import UIKit
typealias PlatformView = UIView
#elseif os(macOS)
import AppKit
typealias PlatformView = NSView
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
        if let scene = scene as? GameScene { 
            scene.shakeCamera(intensity: 20); scene.updateHealthUI()
            if health <= 0 { scene.triggerGameOver() }
        }
        let f = SKAction.repeat(SKAction.sequence([SKAction.fadeAlpha(to: 0.2, duration: 0.05), SKAction.fadeAlpha(to: 1.0, duration: 0.05)]), count: 15)
        self.run(f) { self.invincible = false }
    }
    func reset() { health = 3; invincible = false; self.alpha = 1.0; self.isHidden = false; self.setScale(1.0) }
}

// MARK: - Theme Manager
struct Theme {
    let playerColor: SKColor; let obstacleColor: SKColor
    static let themes: [Theme] = [
        Theme(playerColor: .cyan, obstacleColor: SKColor(red: 1.0, green: 0.1, blue: 0.5, alpha: 1.0)), // JSaB Original
        Theme(playerColor: SKColor(red: 0.8, green: 0.0, blue: 1.0, alpha: 1.0), obstacleColor: .yellow), // Volt
        Theme(playerColor: .white, obstacleColor: SKColor(red: 0.2, green: 1.0, blue: 0.2, alpha: 1.0)), // Matrix
        Theme(playerColor: .blue, obstacleColor: .orange) // Inferno
    ]
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

// MARK: - Game Scene
class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: PlayerNode!; var beatManager: BeatManager!; var obstacleManager: ObstacleManager!
    private var activeKeys = Set<String>(); private var bgPulse = SKNode(); private var uiLayer = SKNode(); private var gameOverLayer = SKNode()
    private var progressBar = SKShapeNode(); private var healthNode = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var totalBeats = 512; private var currentBeat = 0; private var skillModifier: CGFloat = 1.0; private var lastHitTime: TimeInterval = 0; private var lastScaleDownTime: TimeInterval = 0; private var flawlessBeats = 0; private var isGameOver = false
    private let gameCamera = SKCameraNode()
    
    #if os(iOS)
    private var moveTouch: UITouch?; private var joystickCenter: CGPoint?; private var moveVector = CGVector.zero; private let stickBase = SKShapeNode(circleOfRadius: 60); private let stickKnob = SKShapeNode(circleOfRadius: 30)
    #endif
    
    override func didMove(to view: SKView) {
        let savedSkill = UserDefaults.standard.double(forKey: "braxton_skill_level"); self.skillModifier = savedSkill == 0 ? 1.0 : min(CGFloat(savedSkill), 1.0)
        self.backgroundColor = .black; self.physicsWorld.contactDelegate = self
        self.camera = gameCamera; gameCamera.position = CGPoint(x: frame.midX, y: frame.midY); addChild(gameCamera)
        addChild(bgPulse); addChild(uiLayer); addChild(gameOverLayer)
        #if os(iOS)
        stickBase.strokeColor = .white.withAlphaComponent(0.2); stickBase.lineWidth = 2; stickBase.isHidden = true; addChild(stickBase)
        stickKnob.fillColor = .white.withAlphaComponent(0.3); stickKnob.strokeColor = .white.withAlphaComponent(0.5); stickKnob.lineWidth = 1; stickKnob.isHidden = true; addChild(stickKnob)
        #endif
        player = PlayerNode(); player.position = CGPoint(x: frame.midX, y: frame.midY); addChild(player)
        setupUI(); beatManager = BeatManager(bpm: 128); obstacleManager = ObstacleManager(scene: self)
        beatManager.onBeat = { [weak self] index in self?.handleBeat(index) }; beatManager.start()
        #if os(iOS)
        view.isMultipleTouchEnabled = true
        #endif
    }
    private func setupUI() {
        progressBar = SKShapeNode(rectOf: CGSize(width: frame.width, height: 6)); progressBar.fillColor = .cyan; progressBar.position = CGPoint(x: 0, y: frame.height/2 - 3); progressBar.xScale = 0; gameCamera.addChild(progressBar)
        healthNode.fontSize = 20; healthNode.fontColor = .white; healthNode.position = CGPoint(x: -frame.width/2 + 80, y: frame.height/2 - 50); healthNode.text = "HEALTH: 3"; gameCamera.addChild(healthNode)
    }
    func updateHealthUI() { healthNode.text = "HEALTH: \(player.health)" }
    private func updateTheme() {
        let themeIndex = (currentBeat / (totalBeats / Theme.themes.count)) % Theme.themes.count
        let theme = Theme.themes[themeIndex]
        player.fillColor = theme.playerColor
        obstacleManager.currentThemeColor = theme.obstacleColor
        progressBar.fillColor = theme.playerColor
    }
    private func handleBeat(_ index: Int) {
        if isGameOver { return }; currentBeat = index
        player.pulse(); progressBar.xScale = min(CGFloat(index) / CGFloat(totalBeats), 1.0)
        updateTheme()
        let flash = SKShapeNode(rect: frame); flash.position = CGPoint(x: -frame.midX, y: -frame.midY); flash.fillColor = .white; flash.alpha = 0.05; bgPulse.addChild(flash); flash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.1), SKAction.removeFromParent()]))
        flawlessBeats += 1; adjustDifficulty()
        let comb = 1.0 * skillModifier
        if index % Int(max(1, 16/comb)) == 0 { let isH = Bool.random(); obstacleManager.spawnBeam(at: isH ? CGPoint(x: frame.midX, y: CGFloat.random(in: 100...frame.height-100)) : CGPoint(x: CGFloat.random(in: 100...frame.width-100), y: frame.midY), horizontal: isH, speedScale: comb) }
        if index % Int(max(1, 12/comb)) == 0 { obstacleManager.spawnAimedShot(from: CGPoint(x: Bool.random() ? 0 : frame.width, y: CGFloat.random(in: 0...frame.height)), target: player.position, speedScale: comb) }
        if index % Int(max(1, 24/comb)) == 0 { obstacleManager.spawnPulsar(at: CGPoint(x: CGFloat.random(in: 200...frame.width-200), y: CGFloat.random(in: 200...frame.height-200)), speedScale: comb) }
        if skillModifier < 0.8 && index % 16 == 0 { obstacleManager.spawnPowerUp(at: CGPoint(x: CGFloat.random(in: 100...frame.width-100), y: CGFloat.random(in: 100...frame.height-100))) }
    }
    private func adjustDifficulty() { if flawlessBeats >= 26 { skillModifier = min(skillModifier + 0.02, 1.0); flawlessBeats = 0; saveSkill() } }
    private func saveSkill() { UserDefaults.standard.set(Double(skillModifier), forKey: "braxton_skill_level") }
    func shakeCamera(intensity: CGFloat = 12) { 
        gameCamera.run(SKAction.sequence([SKAction.moveBy(x: intensity, y: intensity, duration: 0.04), SKAction.moveBy(x: -intensity*2, y: -intensity*2, duration: 0.04), SKAction.move(to: CGPoint(x: frame.midX, y: frame.midY), duration: 0.04)]))
        let now = CACurrentMediaTime(); if now - lastScaleDownTime > 4.8 { skillModifier = max(skillModifier - 0.02, 0.4); lastScaleDownTime = now; saveSkill() }
        lastHitTime = now; flawlessBeats = 0
    }
    func triggerGameOver() {
        isGameOver = true; let l = SKLabelNode(fontNamed: "AvenirNext-Heavy"); l.text = "IT'S OVER"; l.fontSize = 80; l.fontColor = .red; l.position = .zero; l.alpha = 0; l.zPosition = 100; gameCamera.addChild(l)
        let s = SKLabelNode(fontNamed: "AvenirNext-Bold"); s.text = "Tap to Restart"; s.fontSize = 24; s.fontColor = .white; s.position = CGPoint(x: 0, y: -60); s.alpha = 0; s.zPosition = 100; gameCamera.addChild(s)
        l.run(SKAction.fadeIn(withDuration: 0.8)); s.run(SKAction.sequence([SKAction.wait(forDuration: 1.5), SKAction.fadeIn(withDuration: 0.5)]))
        skillModifier = max(skillModifier - 0.05, 0.4); saveSkill()
    }
    func restartGame() { isGameOver = false; gameCamera.removeAllChildren(); setupUI(); player.position = CGPoint(x: frame.midX, y: frame.midY); player.reset(); updateHealthUI(); beatManager.start() }
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { if isGameOver { restartGame(); return }; for t in touches { let loc = t.location(in: self); if loc.x < frame.width / 2 { if moveTouch == nil { moveTouch = t; joystickCenter = loc; stickBase.position = loc; stickBase.isHidden = false; stickKnob.position = loc; stickKnob.isHidden = false } } else { player.dash(direction: moveVector == .zero ? CGVector(dx: 0, dy: 1) : moveVector) } } }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { if isGameOver { return }; if let t = moveTouch, let c = joystickCenter { let loc = t.location(in: self); let dx = loc.x - c.x; let dy = loc.y - c.y; let d = sqrt(dx*dx + dy*dy); if d > 4 { let maxD: CGFloat = 80.0; let intensity = min(d / maxD, 1.0); moveVector = CGVector(dx: (dx/d)*intensity, dy: (dy/d)*intensity); let kD = min(d, maxD); stickKnob.position = CGPoint(x: c.x + (dx/d)*kD, y: c.y + (dy/d)*kD) } else { moveVector = .zero; stickKnob.position = c } } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { for t in touches { if t == moveTouch { moveTouch = nil; moveVector = .zero; stickBase.isHidden = true; stickKnob.isHidden = true } } }
    private func updateJoystick() { if moveVector != .zero { player.updatePos(to: CGPoint(x: player.position.x + moveVector.dx*15.0, y: player.position.y + moveVector.dy*15.0)) } }
    #elseif os(macOS)
    override func keyDown(with event: NSEvent) { if isGameOver { restartGame(); return }; if let chars = event.charactersIgnoringModifiers { activeKeys.insert(chars.lowercased()) }; if event.keyCode == 49 { dashFromKbd() } }
    override func keyUp(with event: NSEvent) { if let chars = event.charactersIgnoringModifiers { activeKeys.remove(chars.lowercased()) } }
    private var kbdIntensity: CGFloat = 0.0
    private func updateKbdMove() { var dx: CGFloat = 0, dy: CGFloat = 0; if activeKeys.contains("w") { dy += 1 }; if activeKeys.contains("s") { dy -= 1 }; if activeKeys.contains("a") { dx -= 1 }; if activeKeys.contains("d") { dx += 1 }
        if dx != 0 || dy != 0 { kbdIntensity = min(kbdIntensity + 0.05, 1.0); let len = sqrt(dx*dx + dy*dy); let maxSpeed: CGFloat = 16.0; player.updatePos(to: CGPoint(x: player.position.x + (dx/len)*maxSpeed*kbdIntensity, y: player.position.y + (dy/len)*maxSpeed*kbdIntensity)) } else { kbdIntensity = max(kbdIntensity - 0.1, 0.0) } }
    private func dashFromKbd() { var dx: CGFloat = 0, dy: CGFloat = 0; if activeKeys.contains("w") { dy += 1 }; if activeKeys.contains("s") { dy -= 1 }; if activeKeys.contains("a") { dx -= 1 }; if activeKeys.contains("d") { dx += 1 }
        if dx == 0 && dy == 0 { dy = 1 }; let len = sqrt(dx*dx + dy*dy); player.dash(direction: CGVector(dx: dx/len, dy: dy/len)) }
    #endif
    override func update(_ currentTime: TimeInterval) { if isGameOver { return }; beatManager.update(); #if os(macOS)
        updateKbdMove()
        #elseif os(iOS)
        updateJoystick()
        #endif
        player.position.x = max(15, min(frame.width - 15, player.position.x)); player.position.y = max(15, min(frame.height - 15, player.position.y)) }
    func didBegin(_ contact: SKPhysicsContact) { if isGameOver { return }; let catA = contact.bodyA.categoryBitMask; let catB = contact.bodyB.categoryBitMask
        if (catA | catB) == (0x1 << 0 | 0x1 << 1) { player.takeDamage() }
        if (catA | catB) == (0x1 << 0 | 0x1 << 2) { let pNode = (catA == 0x1 << 2) ? contact.bodyA.node : contact.bodyB.node; pNode?.removeFromParent()
            player.run(SKAction.sequence([SKAction.run { self.player.health = min(self.player.health + 1, 3); self.updateHealthUI() }, SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.1), SKAction.wait(forDuration: 3.0), SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.5)])) } }
}

// MARK: - App Entry
#if os(iOS)
struct SpriteKitContainer: UIViewRepresentable {
    let scene: SKScene
    func makeUIView(context: Context) -> SKView { let v = SKView(); v.preferredFramesPerSecond = 120; v.presentScene(scene); return v }
    func updateUIView(_ uiView: SKView, context: Context) {}
}
#elseif os(macOS)
struct SpriteKitContainer: NSViewRepresentable {
    let scene: SKScene
    func makeNSView(context: Context) -> SKView { let v = SKView(); v.preferredFramesPerSecond = 120; v.presentScene(scene); return v }
    func updateNSView(_ nsView: SKView, context: Context) {}
}
#endif
struct ContentView: View {
    let scene: GameScene = { let s = GameScene(); s.size = CGSize(width: 1024, height: 768); s.scaleMode = .aspectFill; return s }()
    var body: some View { SpriteKitContainer(scene: scene).ignoresSafeArea().background(Color.black) }
}
@main
struct BeatsAndShapesApp: App {
    var body: some Scene { WindowGroup { ContentView() }
    #if os(macOS)
    .windowStyle(.hiddenTitleBar)
    #endif
    }
}
