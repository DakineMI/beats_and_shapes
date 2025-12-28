import SwiftUI

/// Modern settings view using SwiftUI and ObservableObject
struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Master Volume
                    VolumeControlView(
                        title: "Master Volume",
                        value: $settingsManager.masterVolume
                    )
                    
                    // Music Volume
                    VolumeControlView(
                        title: "Music Volume",
                        value: $settingsManager.musicVolume
                    )
                    
                    // Sound Effects Volume
                    VolumeControlView(
                        title: "Sound Effects",
                        value: $settingsManager.soundEffectsVolume
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Back button
                Button("Back") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
    }
}

/// Reusable volume control component
struct VolumeControlView: View {
    let title: String
    @Binding var value: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.gray)
                
                Slider(value: $value, in: 0...1)
                    .tint(.cyan)
                
                Image(systemName: "speaker.3.fill")
                    .foregroundColor(.cyan)
                
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}