import StoreKit
import SwiftUI
import Combine

/// StoreKit 3 integration for monetization and IAP (2025+ standards)
@MainActor
class StoreManager: ObservableObject {
    // MARK: - Products and Purchase States
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProducts: [Product] = []
    @Published private(set) var subscriptionStatus: [String: Product.SubscriptionInfo.Status] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchaseState: PurchaseState = .none
    @Published private(set) var restoreState: RestoreState = .none
    
    // MARK: - Product IDs
    enum ProductID: String, CaseIterable {
        // Premium Features
        case premiumUnlock = "premium_unlock"
        case dlcPack1 = "dlc_pack_1"
        case dlcPack2 = "dlc_pack_2"
        case dlcPack3 = "dlc_pack_3"
        
        // Customization
        case customThemePack = "custom_theme_pack"
        case customObstaclePack = "custom_obstacle_pack"
        case customSoundtrackPack = "custom_soundtrack_pack"
        
        // Consumables
        case extraLives5 = "extra_lives_5"
        case extraLives10 = "extra_lives_10"
        case doubleXP = "double_xp"
        case skipLevel = "skip_level"
        
        // Subscriptions
        case monthlyPremium = "premium_monthly"
        case yearlyPremium = "premium_yearly"
        case lifetimePremium = "premium_lifetime"
    }
    
    enum PurchaseState {
        case none
        case purchasing(productId: String)
        case succeeded(productId: String)
        case failed(productId: String, error: Error)
        case restored(productId: String)
    }
    
    enum RestoreState {
        case none
        case restoring
        case succeeded
        case failed(error: Error)
    }
    
    // MARK: - Private Properties
    private var productIds: Set<String> = []
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        setupStoreKit()
        loadProducts()
        listenForTransactions()
        checkPurchasedProducts()
    }
    
    // MARK: - StoreKit Setup
    private func setupStoreKit() {
        // Configure StoreKit 3
        Task { @MainActor in
            await verifyAppStoreReceipt()
        }
    }
    
    private func verifyAppStoreReceipt() async {
        do {
            // Verify receipt with Apple
            let verification = try await AppStore.verifyReceipt()
            
            if verification.verified {
                print("✅ App Store receipt verified")
                await checkPurchasedProducts()
            } else {
                print("⚠️ App Store receipt verification failed")
            }
        } catch {
            print("❌ Receipt verification error: \(error)")
        }
    }
    
    private func listenForTransactions() {
        updateListenerTask = Task { @MainActor in
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: Result<VerificationResult<Transaction>, Error>) async {
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await handleVerifiedTransaction(transaction)
            } else {
                print("⚠️ Transaction verification failed")
            }
        case .failure(let error):
            print("❌ Transaction error: \(error)")
        }
    }
    
    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        switch transaction.productType {
        case .nonConsumable:
            // Handle premium unlock
            if let productID = transaction.productID {
                await handleNonConsumablePurchase(productID: productID)
            }
            
        case .autoRenewable:
            // Handle subscription
            if let productID = transaction.productID {
                await handleSubscriptionUpdate(productID: productID, status: transaction.subscriptionStatus)
            }
            
        case .consumable:
            // Handle consumables (extra lives, XP boost)
            if let productID = transaction.productID {
                await handleConsumablePurchase(productID: productID, quantity: transaction.ownedQuantity)
            }
            
        default:
            print("⚠️ Unknown product type: \(transaction.productType)")
        }
    }
    
    // MARK: - Product Loading
    private func loadProducts() {
        Task { @MainActor in
            isLoadingProducts = true
            
            do {
                let storeProducts = try await Product.products(for: productIds)
                products = storeProducts.sorted { $0.price < $1.price }
                isLoadingProducts = false
                
                print("✅ Loaded \(storeProducts.count) products")
                await checkPurchasedProducts()
                
            } catch {
                isLoadingProducts = false
                print("❌ Failed to load products: \(error)")
                await showAlert(title: "Store Error", message: "Unable to load products. Please try again later.")
            }
        }
    }
    
    private func checkPurchasedProducts() async {
        do {
            let purchased = try await Product.purchasedProducts()
            
            for product in purchased {
                if let productID = product.id {
                    if !purchasedProducts.contains(where: { $0.id == productID }) {
                        purchasedProducts.append(product)
                    }
                }
            }
            
            // Update subscription statuses
            await updateSubscriptionStatuses()
            
            print("✅ Loaded \(purchasedProducts.count) purchased products")
            
        } catch {
            print("❌ Failed to check purchased products: \(error)")
        }
    }
    
    private func updateSubscriptionStatuses() async {
        do {
            let subscriptions = try await Product.subscriptions(for: [
                ProductID.monthlyPremium.rawValue,
                ProductID.yearlyPremium.rawValue,
                ProductID.lifetimePremium.rawValue
            ])
            
            for subscription in subscriptions {
                if let productID = subscription.id,
                   let status = subscription.subscriptionStatus {
                    subscriptionStatus[productID] = status
                }
            }
            
            print("✅ Updated subscription statuses")
            
        } catch {
            print("❌ Failed to update subscription statuses: \(error)")
        }
    }
    
    // MARK: - Purchase Methods
    func purchase(_ productId: ProductID) async {
        guard let product = products.first(where: { $0.id == productId.rawValue }) else {
            await showAlert(title: "Product Not Found", message: "This product is no longer available.")
            return
        }
        
        // Check if already purchased
        if purchasedProducts.contains(where: { $0.id == productId.rawValue }) {
            await showAlert(title: "Already Purchased", message: "You already own this item.")
            return
        }
        
        do {
            purchaseState = .purchasing(productId: productId.rawValue)
            
            let result = try await product.purchase()
            
            switch result {
            case .success:
                purchaseState = .succeeded(productId: productId.rawValue)
                await handlePurchaseSuccess(productId: productId.rawValue)
                
            case .pending:
                print("🔄 Purchase pending for \(productId.rawValue)")
                
            case .userCancelled:
                purchaseState = .none
                print("👤 User cancelled purchase")
                
        default:
            print("⚠️ Unknown product type: \(transaction.productType)")
        }
            
        } catch {
            purchaseState = .failed(productId: productId.rawValue, error: error)
            print("❌ Purchase failed: \(error)")
            await showAlert(title: "Purchase Failed", message: "Unable to complete purchase. Please try again.")
        }
    }
    
    private func handlePurchaseSuccess(productId: String) async {
        // Update purchased products
        await checkPurchasedProducts()
        
        // Unlock features based on product
        await unlockFeaturesForProduct(productId)
        
        // Show success message
        let productName = getProductName(productId)
        await showAlert(title: "Purchase Successful", message: "You've successfully purchased \(productName)!")
        
        // Analytics tracking
        await AnalyticsManager.shared.trackPurchase(productId: productId, value: getProductPrice(productId))
    }
    
    private func unlockFeaturesForProduct(_ productId: String) async {
        switch productId {
        case ProductID.premiumUnlock.rawValue:
            // Unlock all premium features
            await unlockAllPremiumFeatures()
            
        case ProductID.dlcPack1.rawValue:
            await unlockDLCPack(1)
        case ProductID.dlcPack2.rawValue:
            await unlockDLCPack(2)
        case ProductID.dlcPack3.rawValue:
            await unlockDLCPack(3)
            
        case ProductID.customThemePack.rawValue:
            await unlockCustomThemes()
            
        case ProductID.customObstaclePack.rawValue:
            await unlockCustomObstacles()
            
        case ProductID.customSoundtrackPack.rawValue:
            await unlockCustomSoundtracks()
            
        default:
            print("⚠️ Unknown product ID: \(productId)")
        }
    }
    
    private func handleNonConsumablePurchase(productID: String) async {
        // Already handled in handlePurchaseSuccess
        print("✅ Non-consumable purchase completed: \(productID)")
    }
    
    private func handleConsumablePurchase(productID: String, quantity: Int) async {
        switch productID {
        case ProductID.extraLives5.rawValue:
            await addExtraLives(5)
        case ProductID.extraLives10.rawValue:
            await addExtraLives(10)
        case ProductID.doubleXP.rawValue:
            await enableDoubleXP()
        case ProductID.skipLevel.rawValue:
            await enableSkipLevel()
        default:
            print("⚠️ Unknown consumable: \(productID)")
        }
    }
    
    private func handleSubscriptionUpdate(productID: String, status: Product.SubscriptionInfo.Status) async {
        subscriptionStatus[productID] = status
        
        switch status {
        case .subscribed:
            print("✅ Subscription active: \(productID)")
            await enablePremiumFeatures()
            
        case .expired, .inGracePeriod, .revoked:
            print("⚠️ Subscription issue: \(productID) - \(status)")
            await disablePremiumFeatures()
            
        default:
            print("ℹ️ Subscription status: \(productID) - \(status)")
        }
    }
    
    // MARK: - Feature Unlocking
    private func unlockAllPremiumFeatures() async {
        UserDefaults.standard.set(true, forKey: "premium_unlocked")
        await enablePremiumFeatures()
    }
    
    private func enablePremiumFeatures() async {
        // Enable all premium features
        UserDefaults.standard.set(true, forKey: "all_levels_unlocked")
        UserDefaults.standard.set(true, forKey: "custom_themes_enabled")
        UserDefaults.standard.set(true, forKey: "custom_obstacles_enabled")
        UserDefaults.standard.set(true, forKey: "custom_soundtracks_enabled")
        
        NotificationCenter.default.post(name: .premiumFeaturesUnlocked, object: nil)
        print("✅ Premium features enabled")
    }
    
    private func disablePremiumFeatures() async {
        UserDefaults.standard.set(false, forKey: "premium_unlocked")
        NotificationCenter.default.post(name: .premiumFeaturesDisabled, object: nil)
        print("⚠️ Premium features disabled")
    }
    
    private func unlockDLCPack(_ packNumber: Int) async {
        UserDefaults.standard.set(true, forKey: "dlc_pack_\(packNumber)_unlocked")
        NotificationCenter.default.post(name: .dlcPackUnlocked, object: packNumber)
        print("✅ DLC Pack \(packNumber) unlocked")
    }
    
    private func unlockCustomThemes() async {
        UserDefaults.standard.set(true, forKey: "custom_themes_enabled")
        NotificationCenter.default.post(name: .customThemesUnlocked, object: nil)
        print("✅ Custom themes unlocked")
    }
    
    private func unlockCustomObstacles() async {
        UserDefaults.standard.set(true, forKey: "custom_obstacles_enabled")
        NotificationCenter.default.post(name: .customObstaclesUnlocked, object: nil)
        print("✅ Custom obstacles unlocked")
    }
    
    private func unlockCustomSoundtracks() async {
        UserDefaults.standard.set(true, forKey: "custom_soundtracks_enabled")
        NotificationCenter.default.post(name: .customSoundtracksUnlocked, object: nil)
        print("✅ Custom soundtracks unlocked")
    }
    
    private func addExtraLives(_ count: Int) async {
        let currentLives = UserDefaults.standard.integer(forKey: "extra_lives")
        UserDefaults.standard.set(currentLives + count, forKey: "extra_lives")
        NotificationCenter.default.post(name: .extraLivesAdded, object: count)
        print("✅ Added \(count) extra lives")
    }
    
    private func enableDoubleXP() async {
        UserDefaults.standard.set(true, forKey: "double_xp_enabled")
        NotificationCenter.default.post(name: .doubleXPEnabled, object: nil)
        print("✅ Double XP enabled")
    }
    
    private func enableSkipLevel() async {
        UserDefaults.standard.set(true, forKey: "skip_level_enabled")
        NotificationCenter.default.post(name: .skipLevelEnabled, object: nil)
        print("✅ Skip level enabled")
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        restoreState = .restoring
        
        do {
            try await AppStore.sync()
            
            // Refresh purchased products after restore
            await checkPurchasedProducts()
            
            restoreState = .succeeded
            await showAlert(title: "Restore Successful", message: "Your purchases have been restored.")
            
        } catch {
            restoreState = .failed(error: error)
            await showAlert(title: "Restore Failed", message: "Unable to restore purchases. Please try again.")
        }
    }
    
    // MARK: - Product Information
    func getProductName(_ productId: String) -> String {
        switch productId {
        case ProductID.premiumUnlock.rawValue: return "Premium Unlock"
        case ProductID.dlcPack1.rawValue: return "DLC Pack 1"
        case ProductID.dlcPack2.rawValue: return "DLC Pack 2"
        case ProductID.dlcPack3.rawValue: return "DLC Pack 3"
        case ProductID.customThemePack.rawValue: return "Custom Theme Pack"
        case ProductID.customObstaclePack.rawValue: return "Custom Obstacle Pack"
        case ProductID.customSoundtrackPack.rawValue: return "Custom Soundtrack Pack"
        case ProductID.extraLives5.rawValue: return "5 Extra Lives"
        case ProductID.extraLives10.rawValue: return "10 Extra Lives"
        case ProductID.doubleXP.rawValue: return "Double XP"
        case ProductID.skipLevel.rawValue: return "Skip Level"
        case ProductID.monthlyPremium.rawValue: return "Monthly Premium"
        case ProductID.yearlyPremium.rawValue: return "Yearly Premium"
        case ProductID.lifetimePremium.rawValue: return "Lifetime Premium"
        default: return productId
        }
    }
    
    func getProductPrice(_ productId: String) -> Decimal? {
        return products.first { $0.id == productId }?.price
    }
    
    func isProductPurchased(_ productId: ProductID) -> Bool {
        return purchasedProducts.contains { $0.id == productId.rawValue }
    }
    
    func isSubscriptionActive(_ productId: ProductID) -> Bool {
        guard let status = subscriptionStatus[productId.rawValue] else { return false }
        return status == .subscribed
    }
    
    func hasPremiumAccess() -> Bool {
        return isProductPurchased(.premiumUnlock) ||
               isSubscriptionActive(.monthlyPremium) ||
               isSubscriptionActive(.yearlyPremium) ||
               isSubscriptionActive(.lifetimePremium)
    }
    
    // MARK: - UI Integration
    func purchaseProductView(_ productId: ProductID) -> some View {
        PurchaseProductView(
            productId: productId,
            storeManager: self
        )
    }
    
    func subscriptionView(_ productId: ProductID) -> some View {
        SubscriptionView(
            productId: productId,
            storeManager: self
        )
    }
    
    func restorePurchasesView() -> some View {
        RestorePurchasesView(storeManager: self)
    }
    
    // MARK: - Analytics
    private func showAlert(title: String, message: String) async {
        // Implementation would show appropriate UI alert
        print("📢 \(title): \(message)")
    }
}

// MARK: - Store Views
struct PurchaseProductView: View {
    let productId: StoreManager.ProductID
    let storeManager: StoreManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Purchase")
                .font(.title)
                .fontWeight(.bold)
            
            if let product = storeManager.products.first(where: { $0.id == productId.rawValue }) {
                VStack(spacing: 15) {
                    Text(product.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(product.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Button("Purchase") {
                        Task {
                            await storeManager.purchase(productId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(storeManager.isProductPurchased(productId))
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                }
            }
        }
        .padding()
    }
}

struct SubscriptionView: View {
    let productId: StoreManager.ProductID
    let storeManager: StoreManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Premium Subscription")
                .font(.title)
                .fontWeight(.bold)
            
            if let product = storeManager.products.first(where: { $0.id == productId.rawValue }) {
                VStack(spacing: 15) {
                    Text(product.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(product.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let subscription = product.subscription {
                        Text("Billed \(subscription.subscriptionPeriod.description)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Button(storeManager.isSubscriptionActive(productId) ? "Manage" : "Subscribe") {
                        Task {
                            if storeManager.isSubscriptionActive(productId) {
                                // Open subscription management
                                await manageSubscription()
                            } else {
                                await storeManager.purchase(productId)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(storeManager.isSubscriptionActive(productId) ? .orange : .green)
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                }
            }
        }
        .padding()
    }
    
    private func manageSubscription() async {
        // Implementation would open App Store subscription management
        print("🔧 Opening subscription management")
    }
}

struct RestorePurchasesView: View {
    let storeManager: StoreManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Restore Purchases")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Restore any previously made purchases on this device.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Restore Purchases") {
                Task {
                    await storeManager.restorePurchases()
                }
            }
            .buttonStyle(.bordered)
            .disabled(storeManager.restoreState == .restoring)
            
            if storeManager.restoreState == .restoring {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Restoring...")
                }
            } else if storeManager.restoreState == .succeeded {
                Text("✅ Purchases restored!")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let premiumFeaturesUnlocked = Notification.Name("premiumFeaturesUnlocked")
    static let premiumFeaturesDisabled = Notification.Name("premiumFeaturesDisabled")
    static let dlcPackUnlocked = Notification.Name("dlcPackUnlocked")
    static let customThemesUnlocked = Notification.Name("customThemesUnlocked")
    static let customObstaclesUnlocked = Notification.Name("customObstaclesUnlocked")
    static let customSoundtracksUnlocked = Notification.Name("customSoundtracksUnlocked")
    static let extraLivesAdded = Notification.Name("extraLivesAdded")
    static let doubleXPEnabled = Notification.Name("doubleXPEnabled")
    static let skipLevelEnabled = Notification.Name("skipLevelEnabled")
}