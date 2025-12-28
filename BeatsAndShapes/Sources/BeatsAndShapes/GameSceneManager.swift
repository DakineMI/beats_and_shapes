import Foundation
import SwiftUI
import SpriteKit

/// Modern game scene manager using SwiftUI and Swift concurrency
@MainActor
class GameSceneManager: ObservableObject, GameSceneManagerProtocol {
    @Published var currentScene: SKScene?
    @Published var gameState: GameState = .splash
    @Published var navigationPath = NavigationPath()
    
    @Injected(\.gameDataRepository) private var gameData
    @Injected(\.progressManager) private var progressManager
    
    enum GameState: Hashable {
        case splash
        case menu
        case playing(song: Song)
        case paused
        case gameOver(score: Int, song: Song)
        case settings
    }
    
    func showSplash(completion: @escaping () -> Void) {
        let splashScene = SplashScreenScene()
        splashScene.size = CGSize(width: GameConstants.sceneWidth, height: GameConstants.sceneHeight)
        splashScene.scaleMode = .aspectFill
        splashScene.onFinished = {
            self.gameState = .menu
            completion()
        }
        
        currentScene = splashScene
    }
    
    func showMenu() {
        let menuScene = MenuScene()
        menuScene.size = CGSize(width: GameConstants.sceneWidth, height: GameConstants.sceneHeight)
        menuScene.scaleMode = .aspectFill
        menuScene.onSongSelected = { [weak self] song in
            self?.startGame(with: song)
        }
        
        currentScene = menuScene
        gameState = .menu
    }
    
    func startGame(with song: Song) {
        let gameScene = ModernGameScene(song: song)
        gameScene.size = CGSize(width: GameConstants.sceneWidth, height: GameConstants.sceneHeight)
        gameScene.scaleMode = .aspectFill
        gameScene.onGameEnded = { [weak self] finalScore in
            self?.handleGameEnd(score: finalScore, song: song)
        }
        
        currentScene = gameScene
        gameState = .playing(song: song)
    }
    
    private func handleGameEnd(score: Int, song: Song) {
        progressManager.saveScore(score, for: song.id)
        gameState = .gameOver(score: score, song: song)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showMenu()
        }
    }
    
    func pauseGame() {
        gameState = .paused
    }
    
    func resumeGame() {
        if case .playing(let song) = gameState {
            gameState = .playing(song: song)
        }
    }
    
    func showSettings() {
        gameState = .settings
    }
}