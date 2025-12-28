import CloudKit
import SwiftUI
import Combine

/// CloudKit integration for cross-platform progress sync (2025+ standards)
@MainActor
class CloudSyncManager: ObservableObject {
    private let container: CKContainer
    private let database: CKDatabase
    private let privateDatabase: CKDatabase
    
    // MARK: - Published State
    @Published private(set) var syncStatus: SyncStatus = .disconnected
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var conflicts: [SyncConflict] = []
    @Published var hasCloudChanges: Bool = false
    
    // MARK: - Sync Data Types
    struct CloudGameData: Codable {
        let highestUnlockedLevel: Int
        let highScores: [String: Int]
        let settings: GameSettings
        let customLevels: [CustomLevel]
        let achievements: [Achievement]
        let playtime: TimeInterval
        let lastPlayedLevel: String
        let gameVersion: String
        let platform: String
        let deviceId: String
        
        struct GameSettings: Codable {
            var masterVolume: Float = 1.0
            var musicVolume: Float = 0.8
            var soundEffectsVolume: Float = 0.7
            var colorblindMode: String = "normal"
            var reduceMotion: Bool = false
            var hapticFeedback: Bool = true
            var difficultyPreference: String = "normal"
        }
        
        struct CustomLevel: Codable, Identifiable {
            let id: UUID
            let name: String
            let creator: String
            let bpm: Double
            let duration: TimeInterval
            let difficulty: String
            let createdAt: Date
            let downloadCount: Int
            let rating: Float
            let data: Data // Encoded level data
        }
        
        struct Achievement: Codable, Identifiable {
            let id: String
            let name: String
            let description: String
            let unlockedAt: Date?
            let progress: Double // 0-1
            let totalRequired: Int
            let currentProgress: Int
            let points: Int
            let rarity: String // common, rare, epic, legendary
            let icon: String // SF Symbol name
        }
    }
    
    enum SyncStatus: String, CaseIterable {
        case disconnected = "disconnected"
        case connecting = "connecting"
        case syncing = "syncing"
        case connected = "connected"
        case error = "error"
        case conflict = "conflict"
        
        var isReady: Bool {
            switch self {
            case .connected: return true
            default: return false
            }
        }
        
        var displayText: String {
            NSLocalizedString(rawValue.capitalized, comment: "")
        }
        
        var systemImage: String {
            switch self {
            case .disconnected: return "icloud.slash"
            case .connecting: return "icloud.and.arrow.up"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .connected: return "icloud.and.arrow.up"
            case .error: return "icloud.slash"
            case .conflict: return "exclamationmark.triangle"
            }
        }
    }
    
    struct SyncConflict: Identifiable {
        let id: UUID = UUID()
        let type: ConflictType
        let localData: Any
        let cloudData: Any
        let timestamp: Date
        
        enum ConflictType {
            case levelProgress
            case highScore
            case settings
            case achievement
        }
    }
    
    private init() {
        // Initialize CloudKit container
        container = CKContainer(identifier: "com.madbadbrax.beatsandshapes")
        database = container.privateCloudDatabase
        privateDatabase = container.publicCloudDatabase
        
        setupCloudKit()
        startAutoSync()
    }
    
    // MARK: - CloudKit Setup
    private func setupCloudKit() {
        // Check account status
        container.accountStatus { status, error in
            Task { @MainActor in
                if let error = error {
                    self.handleCloudError(error)
                } else {
                    await self.handleAccountStatus(status)
                }
            }
        }
        
        // Setup notifications for remote changes
        setupRemoteNotifications()
    }
    
    private func setupRemoteNotifications() {
        // Subscribe to cloud database changes
        let subscription = CKQuerySubscription(recordType: "CloudGameData", predicate: NSPredicate(value: true, comparison: .equalTo))
        subscription.notificationInfo?.shouldSendContentAvailable = true
        subscription.subscriptionID = "cloud_game_data_changes"
        
        database.save(subscription) { subscription, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Failed to create CloudKit subscription: \(error)")
                } else {
                    print("✅ CloudKit subscription created")
                }
            }
        }
    }
    
    private func handleAccountStatus(_ status: CKAccountStatus) async {
        switch status {
        case .available:
            syncStatus = .connected
            await performFullSync()
        case .noAccount:
            syncStatus = .disconnected
            print("📱 No iCloud account available")
        case .restricted:
            syncStatus = .error
            print("🔒 iCloud account restricted")
        case .temporarilyUnavailable:
            syncStatus = .disconnected
            print("🔄 iCloud temporarily unavailable")
        case .couldNotDetermine:
            syncStatus = .error
            print("❓ Could not determine iCloud status")
        @unknown default:
            syncStatus = .error
            print("❓ Unknown iCloud account status")
        }
    }
    
    // MARK: - Sync Operations
    func performFullSync() async {
        guard syncStatus == .connected else { return }
        
        syncStatus = .syncing
        
        do {
            // Fetch all cloud data
            let cloudData = try await fetchAllCloudData()
            
            // Merge with local data
            await mergeCloudData(cloudData)
            
            // Push local changes to cloud
            try await pushLocalChanges()
            
            syncStatus = .connected
            lastSyncDate = Date()
            hasCloudChanges = false
            
            print("✅ Cloud sync completed")
            
        } catch {
            await handleSyncError(error)
        }
    }
    
    private func fetchAllCloudData() async throws -> CloudGameData? {
        let query = CKQuery(recordType: "CloudGameData", predicate: NSPredicate(value: true, comparison: .equalTo))
        
        let result = try await database.records(matching: query)
        
        guard let record = result.matchResults.first else {
            return nil
        }
        
        return try decodeCloudRecord(record)
    }
    
    private func mergeCloudData(_ cloudData: CloudGameData?) async {
        guard let cloudData = cloudData else { return }
        
        // Get local data
        let localData = getLocalGameData()
        
        // Merge and detect conflicts
        let mergedData = mergeGameData(local: localData, cloud: cloudData)
        
        // Apply merged data locally
        await applyMergedData(mergedData)
        
        // Handle any conflicts
        if !conflicts.isEmpty {
            await resolveConflicts()
        }
    }
    
    private func mergeGameData(local: CloudGameData, cloud: CloudGameData) -> CloudGameData {
        var conflicts: [SyncConflict] = []
        var mergedData = localData
        
        // Merge highest unlocked level
        if cloud.highestUnlockedLevel > local.highestUnlockedLevel {
            conflicts.append(SyncConflict(
                type: .levelProgress,
                localData: local.highestUnlockedLevel,
                cloudData: cloud.highestUnlockedLevel,
                timestamp: Date()
            ))
            mergedData.highestUnlockedLevel = cloud.highestUnlockedLevel
        }
        
        // Merge high scores
        for (songId, localScore) in local.highScores {
            if let cloudScore = cloud.highScores[songId] {
                if cloudScore > localScore {
                    conflicts.append(SyncConflict(
                        type: .highScore,
                        localData: localScore,
                        cloudData: cloudScore,
                        timestamp: Date()
                    ))
                }
            }
        }
        mergedData.highScores = mergeHighScores(local: local.highScores, cloud: cloud.highScores)
        
        // Merge settings
        mergedData.settings = mergeSettings(local: local.settings, cloud: cloud.settings)
        
        // Merge achievements
        mergedData.achievements = mergeAchievements(local: local.achievements, cloud: cloud.achievements)
        
        self.conflicts = conflicts
        return mergedData
    }
    
    private func mergeHighScores(local: [String: Int], cloud: [String: Int]) -> [String: Int] {
        var merged = local
        
        for (songId, cloudScore) in cloud {
            if let localScore = local[songId] {
                merged[songId] = max(localScore, cloudScore)
            } else {
                merged[songId] = cloudScore
            }
        }
        
        return merged
    }
    
    private func mergeSettings(local: CloudGameData.GameSettings, cloud: CloudGameData.GameSettings) -> CloudGameData.GameSettings {
        return CloudGameData.GameSettings(
            masterVolume: max(local.masterVolume, cloud.masterVolume),
            musicVolume: max(local.musicVolume, cloud.musicVolume),
            soundEffectsVolume: max(local.soundEffectsVolume, cloud.soundEffectsVolume),
            colorblindMode: cloud.colorblindMode, // Use cloud preference
            reduceMotion: cloud.reduceMotion,
            hapticFeedback: cloud.hapticFeedback,
            difficultyPreference: cloud.difficultyPreference
        )
    }
    
    private func mergeAchievements(local: [CloudGameData.Achievement], cloud: [CloudGameData.Achievement]) -> [CloudGameData.Achievement] {
        var mergedAchievements = local
        let localIds = Set(local.map { $0.id })
        
        for cloudAchievement in cloud {
            if !localIds.contains(cloudAchievement.id) {
                mergedAchievements.append(cloudAchievement)
            } else if let localAchievement = mergedAchievements.first(where: { $0.id == cloudAchievement.id }) {
                // Merge progress
                mergedAchievements[mergedAchievements.firstIndex(of: localAchievement)!] = CloudGameData.Achievement(
                    id: localAchievement.id,
                    name: localAchievement.name,
                    description: localAchievement.description,
                    unlockedAt: localAchievement.unlockedAt ?? cloudAchievement.unlockedAt,
                    progress: max(localAchievement.progress, cloudAchievement.progress),
                    totalRequired: localAchievement.totalRequired,
                    currentProgress: max(localAchievement.currentProgress, cloudAchievement.currentProgress),
                    points: localAchievement.points,
                    rarity: localAchievement.rarity,
                    icon: localAchievement.icon
                )
            }
        }
        
        return mergedAchievements
    }
    
    private func pushLocalChanges() async throws {
        let localData = getLocalGameData()
        
        let record = try encodeCloudRecord(localData)
        
        try await database.save(record)
        print("✅ Pushed local changes to CloudKit")
    }
    
    // MARK: - Data Encoding/Decoding
    private func encodeCloudRecord(_ data: CloudGameData) throws -> CKRecord {
        let record = CKRecord(recordType: "CloudGameData")
        
        record["highestUnlockedLevel"] = data.highestUnlockedLevel
        record["highScores"] = try JSONEncoder().encode(data.highScores)
        record["settings"] = try JSONEncoder().encode(data.settings)
        record["customLevels"] = try JSONEncoder().encode(data.customLevels)
        record["achievements"] = try JSONEncoder().encode(data.achievements)
        record["playtime"] = data.playtime
        record["lastPlayedLevel"] = data.lastPlayedLevel
        record["gameVersion"] = data.gameVersion
        record["platform"] = data.platform
        record["deviceId"] = data.deviceId
        record["lastModified"] = Date()
        
        return record
    }
    
    private func decodeCloudRecord(_ record: CKRecord) throws -> CloudGameData {
        guard let highScoresData = record["highScores"] as? Data,
              let settingsData = record["settings"] as? Data,
              let customLevelsData = record["customLevels"] as? Data,
              let achievementsData = record["achievements"] as? Data else {
            throw CloudError.decodingFailed
        }
        
        return CloudGameData(
            highestUnlockedLevel: record["highestUnlockedLevel"] as? Int ?? 0,
            highScores: try JSONDecoder().decode([String: Int].self, from: highScoresData),
            settings: try JSONDecoder().decode(CloudGameData.GameSettings.self, from: settingsData),
            customLevels: try JSONDecoder().decode([CloudGameData.CustomLevel].self, from: customLevelsData),
            achievements: try JSONDecoder().decode([CloudGameData.Achievement].self, from: achievementsData),
            playtime: record["playtime"] as? TimeInterval ?? 0,
            lastPlayedLevel: record["lastPlayedLevel"] as? String ?? "",
            gameVersion: record["gameVersion"] as? String ?? "1.0.0",
            platform: record["platform"] as? String ?? "unknown",
            deviceId: record["deviceId"] as? String ?? UIDevice.current.identifierForVendor ?? UUID().uuidString
        )
    }
    
    private func getLocalGameData() -> CloudGameData {
        // Load local game data from UserDefaults or local storage
        return CloudGameData(
            highestUnlockedLevel: ProgressManager.getHighestUnlocked(),
            highScores: getAllLocalHighScores(),
            settings: loadLocalSettings(),
            customLevels: loadLocalCustomLevels(),
            achievements: loadLocalAchievements(),
            playtime: getLocalPlaytime(),
            lastPlayedLevel: UserDefaults.standard.string(forKey: "lastPlayedLevel") ?? "",
            gameVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            platform: UIDevice.current.systemName,
            deviceId: UIDevice.current.identifierForVendor ?? UUID().uuidString
        )
    }
    
    private func getAllLocalHighScores() -> [String: Int] {
        // Implementation to gather all local high scores
        var scores: [String: Int] = [:]
        
        for i in 0..<100 {
            let songId = "s\(i)"
            scores[songId] = ProgressManager.getHighScore(for: songId)
        }
        
        return scores
    }
    
    private func loadLocalSettings() -> CloudGameData.GameSettings {
        return CloudGameData.GameSettings(
            masterVolume: UserDefaults.standard.float(forKey: "master_volume"),
            musicVolume: UserDefaults.standard.float(forKey: "music_volume"),
            soundEffectsVolume: UserDefaults.standard.float(forKey: "sfx_volume"),
            colorblindMode: UserDefaults.standard.string(forKey: "colorblind_mode") ?? "normal",
            reduceMotion: UserDefaults.standard.bool(forKey: "reduce_motion"),
            hapticFeedback: UserDefaults.standard.bool(forKey: "haptic_feedback"),
            difficultyPreference: UserDefaults.standard.string(forKey: "difficulty_preference") ?? "normal"
        )
    }
    
    private func loadLocalCustomLevels() -> [CloudGameData.CustomLevel] {
        // Load custom levels from local storage
        // Implementation would load from Documents/CustomLevels/
        return []
    }
    
    private func loadLocalAchievements() -> [CloudGameData.Achievement] {
        // Load achievements from local storage
        // Implementation would load from UserDefaults or local storage
        return []
    }
    
    private func getLocalPlaytime() -> TimeInterval {
        return UserDefaults.standard.double(forKey: "total_playtime")
    }
    
    private func applyMergedData(_ data: CloudGameData) async {
        // Apply merged data to local game state
        ProgressManager.saveScore(data.highestUnlockedLevel, for: "sync_progress")
        
        // Apply settings
        UserDefaults.standard.set(data.settings.masterVolume, forKey: "master_volume")
        UserDefaults.standard.set(data.settings.musicVolume, forKey: "music_volume")
        UserDefaults.standard.set(data.settings.soundEffectsVolume, forKey: "sfx_volume")
        UserDefaults.standard.set(data.settings.colorblindMode, forKey: "colorblind_mode")
        UserDefaults.standard.set(data.settings.reduceMotion, forKey: "reduce_motion")
        UserDefaults.standard.set(data.settings.hapticFeedback, forKey: "haptic_feedback")
        UserDefaults.standard.set(data.settings.difficultyPreference, forKey: "difficulty_preference")
        
        // Apply achievements
        for achievement in data.achievements {
            await saveAchievementLocally(achievement)
        }
        
        print("✅ Applied merged cloud data locally")
    }
    
    private func saveAchievementLocally(_ achievement: CloudGameData.Achievement) async {
        // Save achievement to local storage
        let achievementData = try? JSONEncoder().encode(achievement)
        UserDefaults.standard.set(achievementData, forKey: "achievement_\(achievement.id)")
        
        // Notify achievement unlock
        NotificationCenter.default.post(
            name: .achievementUnlocked,
            object: achievement
        )
    }
    
    // MARK: - Conflict Resolution
    private func resolveConflicts() async {
        for conflict in conflicts {
            await resolveConflict(conflict)
        }
    }
    
    private func resolveConflict(_ conflict: SyncConflict) async {
        switch conflict.type {
        case .levelProgress:
            // Use the higher value from cloud or local
            if let cloudValue = conflict.cloudData as? Int,
               let localValue = conflict.localData as? Int {
                let resolvedValue = max(cloudValue, localValue)
                ProgressManager.saveScore(resolvedValue, for: "sync_progress")
            }
            
        case .highScore:
            // Use the higher score
            if let cloudValue = conflict.cloudData as? Int,
               let localValue = conflict.localData as? Int {
                let resolvedValue = max(cloudValue, localValue)
                ProgressManager.saveScore(resolvedValue, for: "conflict_resolution")
            }
            
        default:
            // For other conflicts, default to cloud data
            print("🔄 Resolved conflict with cloud data for type: \(conflict.type)")
        }
    }
    
    // MARK: - Auto Sync
    private func startAutoSync() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                if self.syncStatus == .connected {
                    await self.performQuickSync()
                }
            }
        }
    }
    
    private func performQuickSync() async {
        // Quick sync for recent changes only
        guard let lastSync = lastSyncDate else {
            await performFullSync()
            return
        }
        
        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        if timeSinceLastSync > 300 { // 5 minutes
            await performFullSync()
        }
    }
    
    // MARK: - Error Handling
    private func handleSyncError(_ error: Error) async {
        syncStatus = .error
        
        if let cloudError = error as? CloudError {
            await handleCloudError(cloudError)
        } else {
            print("❌ Sync error: \(error.localizedDescription)")
        }
    }
    
    private func handleCloudError(_ error: CloudError) async {
        switch error {
        case .networkUnavailable:
            syncStatus = .disconnected
            print("📶 Cloud network unavailable")
            
        case .quotaExceeded:
            syncStatus = .error
            print("📦 CloudKit quota exceeded")
            
        case .decodingFailed:
            syncStatus = .error
            print("🔓 Cloud data decoding failed")
            
        case .authenticationFailed:
            syncStatus = .disconnected
            print("🔐 CloudKit authentication failed")
        }
    }
}

// MARK: - Cloud Errors
enum CloudError: Error, LocalizedError {
    case networkUnavailable
    case quotaExceeded
    case decodingFailed
    case authenticationFailed
    case permissionDenied
    case recordNotFound
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Cloud service is currently unavailable"
        case .quotaExceeded:
            return "Cloud storage quota exceeded"
        case .decodingFailed:
            return "Failed to decode cloud data"
        case .authenticationFailed:
            return "Cloud authentication failed"
        case .permissionDenied:
            return "Cloud access permission denied"
        case .recordNotFound:
            return "Cloud record not found"
        case .rateLimited:
            return "Cloud service rate limited"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let cloudSyncChanged = Notification.Name("cloudSyncChanged")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
    static let customLevelDownloaded = Notification.Name("customLevelDownloaded")
}