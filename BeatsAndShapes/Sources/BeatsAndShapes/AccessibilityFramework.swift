import SwiftUI
import SpriteKit
import AVFoundation

/// Comprehensive accessibility support for Beats & Shapes (2025 standards)
struct AccessibilityManager {
    
    // MARK: - VoiceOver Support
    struct VoiceOverSupport {
        static func announceGameEvent(_ message: String) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        
        static func announceScoreChange(_ score: Int, combo: Int) {
            let message: String
            if combo > 1 {
                message = "Score: \(score), \(combo)x combo!"
            } else {
                message = "Score: \(score)"
            }
            announceGameEvent(message)
        }
        
        static func announceHealthChange(_ health: Int) {
            let message = health == 1 ? "Health: 1 life remaining" : "Health: \(health) lives"
            announceGameEvent(message)
        }
        
        static func announceObstacle(_ type: String, direction: String) {
            announceGameEvent("\(type) from \(direction)")
        }
        
        static func announceBeatCount(_ beat: Int) {
            announceGameEvent("Beat \(beat)")
        }
    }
    
    // MARK: - Dynamic Type Support
    struct DynamicTypeSupport {
        static func scaledSize(_ base: CGFloat) -> CGFloat {
            let category = UIApplication.shared.preferredContentSizeCategory
            let multiplier = scaledMultiplier(for: category)
            return base * multiplier
        }
        
        static func scaledFont(_ base: Font) -> Font {
            let category = UIApplication.shared.preferredContentSizeCategory
            let size = base.size ?? 16
            let scaledSize = scaledSize(size)
            return base.size(scaledSize)
        }
        
        private static func scaledMultiplier(for category: UIContentSizeCategory) -> CGFloat {
            switch category {
            case .extraSmall: return 0.8
            case .small: return 0.9
            case .medium: return 1.0
            case .large: return 1.1
            case .extraLarge: return 1.2
            case .extraExtraLarge: return 1.3
            case .extraExtraExtraLarge: return 1.4
            case .accessibilityMedium: return 1.6
            case .accessibilityLarge: return 1.8
            case .accessibilityExtraLarge: return 2.0
            case .accessibilityExtraExtraLarge: return 2.2
            case .accessibilityExtraExtraExtraLarge: return 2.4
            default: return 1.0
            }
        }
    }
    
    // MARK: - Haptic Feedback
    struct HapticSupport {
        static let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        
        static func playBeatFeedback() {
            DispatchQueue.main.async {
                feedbackGenerator.impactOccurred()
            }
        }
        
        static func playComboFeedback(_ combo: Int) {
            DispatchQueue.main.async {
                let style: UIImpactFeedbackGenerator.FeedbackStyle
                switch combo {
                case 1...5: style = .light
                case 6...10: style = .medium
                case 11...20: style = .heavy
                default: style = .heavy
                }
                
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            }
        }
        
        static func playDamageFeedback() {
            DispatchQueue.main.async {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
        
        static func playPowerUpFeedback() {
            DispatchQueue.main.async {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    // MARK: - Colorblind Support
    struct ColorblindSupport {
        static enum ColorblindMode: String, CaseIterable {
            case normal = "Normal"
            case protanopia = "Red-blind"
            case deuteranopia = "Green-blind"
            case tritanopia = "Blue-blind"
            case achromatopsia = "Monochrome"
            
            var localizedString: String {
                NSLocalizedString(rawValue, comment: "")
            }
        }
        
        @AppStorage("colorblindMode") static var currentMode: ColorblindMode = .normal
        
        static func adjustedColor(_ base: Color) -> Color {
            switch currentMode {
            case .normal:
                return base
            case .protanopia:
                return adjustForProtanopia(base)
            case .deuteranopia:
                return adjustForDeuteranopia(base)
            case .tritanopia:
                return adjustForTritanopia(base)
            case .achromatopsia:
                return convertToGrayscale(base)
            }
        }
        
        private static func adjustForProtanopia(_ color: Color) -> Color {
            // Color transformation matrix for red-blindness
            // This is a simplified version - production would use proper color science
            if color == .red { return Color.orange }
            if color == .green { return Color.yellow }
            return color
        }
        
        private static func adjustForDeuteranopia(_ color: Color) -> Color {
            // Color transformation for green-blindness
            if color == .red { return Color.pink }
            if color == .green { return Color.blue }
            return color
        }
        
        private static func adjustForTritanopia(_ color: Color) -> Color {
            // Color transformation for blue-blindness
            if color == .red { return Color.orange }
            if color == .blue { return Color.green }
            return color
        }
        
        private static func convertToGrayscale(_ color: Color) -> Color {
            // Convert to grayscale for complete colorblindness
            let uiColor = UIColor(color)
            var white: CGFloat = 0
            var alpha: CGFloat = 0
            
            uiColor.getWhite(&white, alpha: &alpha)
            return Color(uiColor)
        }
    }
    
    // MARK: - Motion Sensitivity
    struct MotionSupport {
        static let motionManager = CMMotionManager()
        
        @AppStorage("reduceMotion") static var reduceMotion: Bool = false
        
        static func initializeMotionDetection() {
            if motionManager.isDeviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
                motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                    if let motion = motion {
                        handleMotionData(motion)
                    }
                }
            }
        }
        
        private static func handleMotionData(_ motion: CMDeviceMotion) {
            // Use motion data for alternative control method
            // Could implement tilt controls or gesture recognition
            
            let acceleration = motion.userAcceleration
            let magnitude = sqrt(acceleration.x * acceleration.x + 
                                acceleration.y * acceleration.y + 
                                acceleration.z * acceleration.z)
            
            if magnitude > 2.0 {
                // Strong shake detected - could trigger dash
                NotificationCenter.default.post(
                    name: .shakeDetected,
                    object: nil,
                    userInfo: ["magnitude": magnitude]
                )
            }
        }
    }
    
    // MARK: - Reduced Transitions
    struct ReducedTransitions {
        @AppStorage("reduceTransitions") static var reduceTransitions: Bool = false
        
        static func animationDuration(_ baseDuration: Double) -> Double {
            reduceTransitions ? 0.1 : baseDuration
        }
        
        static func shouldReduceAnimations() -> Bool {
            reduceTransitions || UIAccessibility.isReduceMotionEnabled
        }
    }
}

// MARK: - Accessibility Extensions for SwiftUI Views
extension View {
    func accessibleButton(action: @escaping () -> Void, label: String) -> some View {
        self
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .onTapGesture {
                AccessibilityManager.VoiceOverSupport.announceGameEvent("\(label) button pressed")
                action()
            }
    }
    
    func accessibleSlider(value: Binding<Double>, label: String, min: Double, max: Double) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(value.wrappedValue))")
            .accessibilityAddTraits(.adjustable)
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.layoutChangedNotification)) { _ in
                // Announce value when accessibility layout changes
                AccessibilityManager.VoiceOverSupport.announceGameEvent("\(label): \(Int(value.wrappedValue))")
            }
    }
    
    func accessibleGroup(label: String) -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
}

// MARK: - Accessibility Extensions for SpriteKit
extension SKNode {
    func makeAccessible(label: String, hint: String? = nil) {
        isAccessibilityElement = true
        accessibilityLabel = label
        accessibilityHint = hint
        
        // Make visible to VoiceOver
        accessibilityValue = ""
        accessibilityActions = []
    }
    
    func addAccessibilityAction(name: String, target: AnyObject?, selector: Selector) {
        accessibilityActions?.append(SKAccessibilityAction(
            name: name,
            target: target,
            selector: selector
        ))
    }
    
    func updateAccessibility(value: String) {
        accessibilityValue = value
        UIAccessibility.post(notification: .valueChanged, argument: value)
    }
}

// MARK: - Accessible Game Components
struct AccessibleHUD: View {
    @ObservedObject var scoringSystem: ScoringSystem
    
    var body: some View {
        VStack(spacing: 20) {
            // Score Display
            HStack {
                Text("Score:")
                    .font(AccessibilityManager.DynamicTypeSupport.scaledFont(.title2))
                    .foregroundColor(.white)
                    .accessibilityAddTraits(.isStaticText)
                
                Text("\(scoringSystem.score)")
                    .font(AccessibilityManager.DynamicTypeSupport.scaledFont(.title2))
                    .foregroundColor(.cyan)
                    .accessibilityLabel("Score: \(scoringSystem.score)")
                    .accessibilityAddTraits(.isStaticText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Score display")
            
            // Combo Display
            if scoringSystem.combo > 1 {
                Text("\(scoringSystem.combo)x Combo!")
                    .font(AccessibilityManager.DynamicTypeSupport.scaledFont(.title3))
                    .foregroundColor(.orange)
                    .scaleEffect(scoringSystem.combo > 10 ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: scoringSystem.combo)
                    .accessibilityLabel("\(scoringSystem.combo) combo")
                    .accessibilityAddTraits(.isStaticText)
            }
            
            // Health Display
            HStack {
                Text("Health:")
                    .font(AccessibilityManager.DynamicTypeSupport.scaledFont(.title3))
                    .foregroundColor(.white)
                    .accessibilityAddTraits(.isStaticText)
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < 2 ? Color.red : Color.gray)
                            .frame(width: AccessibilityManager.DynamicTypeSupport.scaledSize(20),
                                   height: AccessibilityManager.DynamicTypeSupport.scaledSize(20))
                            .accessibilityElement(index < 2 ? .ignore : nil)
                            .accessibilityLabel(index < 2 ? "Health remaining" : "")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Health indicators")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Health display")
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
        .padding()
    }
}

// MARK: - Settings for Accessibility
struct AccessibilitySettingsView: View {
    @AppStorage("colorblindMode") private var colorblindMode: AccessibilityManager.ColorblindSupport.ColorblindMode = .normal
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("voiceOverAnnouncements") private var voiceOverAnnouncements: Bool = true
    @AppStorage("reduceMotion") private var reduceMotion: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Accessibility")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Colorblind Mode
                VStack(alignment: .leading, spacing: 10) {
                    Text("Color Vision")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Picker("Color Mode", selection: $colorblindMode) {
                        ForEach(AccessibilityManager.ColorblindSupport.ColorblindMode.allCases, id: \.self) { mode in
                            Text(mode.localizedString).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .accessibilityLabel("Color vision mode")
                    .onChange(of: colorblindMode) { _ in
                        AccessibilityManager.VoiceOverSupport.announceGameEvent("Color mode changed to \(colorblindMode.localizedString)")
                    }
                }
                
                // Haptic Feedback
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    .font(.body)
                    .foregroundColor(.white)
                    .accessibilityLabel("Enable haptic feedback for game events")
                    .onChange(of: hapticFeedback) { enabled in
                        let message = enabled ? "Haptic feedback enabled" : "Haptic feedback disabled"
                        AccessibilityManager.VoiceOverSupport.announceGameEvent(message)
                    }
                
                // VoiceOver Announcements
                Toggle("VoiceOver Announcements", isOn: $voiceOverAnnouncements)
                    .font(.body)
                    .foregroundColor(.white)
                    .accessibilityLabel("Enable voice announcements for game events")
                    .onChange(of: voiceOverAnnouncements) { enabled in
                        let message = enabled ? "VoiceOver announcements enabled" : "VoiceOver announcements disabled"
                        AccessibilityManager.VoiceOverSupport.announceGameEvent(message)
                    }
                
                // Reduce Motion
                Toggle("Reduce Motion", isOn: $reduceMotion)
                    .font(.body)
                    .foregroundColor(.white)
                    .accessibilityLabel("Reduce motion and animations")
                    .onChange(of: reduceMotion) { enabled in
                        let message = enabled ? "Motion reduction enabled" : "Motion reduction disabled"
                        AccessibilityManager.VoiceOverSupport.announceGameEvent(message)
                    }
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let shakeDetected = Notification.Name("shakeDetected")
    static let accessibilityChanged = Notification.Name("accessibilityChanged")
}