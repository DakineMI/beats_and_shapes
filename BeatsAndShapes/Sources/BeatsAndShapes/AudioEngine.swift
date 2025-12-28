import AVFoundation
import Foundation

class AudioEngine {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()
    private let synthNodes: [AVAudioPlayerNode] = (0..<8).map { _ in AVAudioPlayerNode() }
    private let musicPlayer = AVAudioPlayerNode()
    private var isPlaying = false
    private let bpm: Double
    private var prebakedBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var musicFile: AVAudioFile?
    
    struct BeatState {
        let kick: Bool
        let snare: Bool
        let hat: Bool
        let bassNote: Int?
        let leadActive: Bool
        let hornTrigger: Bool
        let fiddleTrigger: Bool
    }
    
    init(bpm: Double, audioFileName: String? = nil) {
        self.bpm = bpm
        setupEngine()
        loadAudioFile(audioFileName)
        prebakeInstruments()
    }
    
    private func loadAudioFile(_ fileName: String?) {
        guard let fileName = fileName else { return }
        
        let extensions = ["mp3", "m4a", "wav", "aac"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: fileName, withExtension: ext) {
                do {
                    musicFile = try AVAudioFile(forReading: url)
                    break
                } catch {
                    print("⚠️ Failed to load audio file \(fileName).\(ext): \(error)")
                }
            }
        }
    }
    
    func getBeatState(index: Int) -> BeatState {
        let seed = Int(truncatingIfNeeded: index)
        var generator = SeededRandomNumberGenerator(seed: seed)
        
        return BeatState(
            kick: true,
            snare: index % 2 == 1,
            hat: true,
            bassNote: index % 4 == 0 ? (index / 4) % 4 : nil,
            leadActive: index % 8 >= 4,
            hornTrigger: index % 16 == 0,
            fiddleTrigger: index % 16 > 12
        )
    }
    
    private func setupEngine() {
        do {
            engine.attach(mixer)
            engine.attach(reverb)
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = 30
            
            engine.attach(delay)
            delay.delayTime = 0.375
            delay.feedback = 20
            delay.wetDryMix = 15
            
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            engine.connect(mixer, to: delay, format: format)
            engine.connect(delay, to: reverb, format: format)
            engine.connect(reverb, to: engine.mainMixerNode, format: format)
            
            for node in synthNodes {
                engine.attach(node)
                engine.connect(node, to: mixer, format: format)
            }
            
            engine.attach(musicPlayer)
            engine.connect(musicPlayer, to: mixer, format: format)
            
            try engine.start()
        } catch {
            print("❌ AudioEngine setup failed: \(error)")
        }
    }
    
    private func prebakeInstruments() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let sampleRate = 44100.0
        
        func bake(id: Int, duration: Double, generator: (Double) -> Float) {
            let frameCount = AVAudioFrameCount(sampleRate * duration)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount
            
            for channel in 0..<Int(format.channelCount) {
                let data = buffer.floatChannelData![channel]
                for i in 0..<Int(frameCount) {
                    data[i] = generator(Double(i) / sampleRate)
                }
            }
            prebakedBuffers[id] = buffer
        }
        
        bake(id: 0, duration: 0.3) { t in
            Float(sin(2.0 * .pi * (60.0 * exp(-10.0 * t)) * t) * exp(-5.0 * t))
        }
        
        bake(id: 1, duration: 0.15) { t in
            Float(Float.random(in: -1...1) * Float(exp(-30.0 * t)) + Float(sin(2.0 * .pi * 200.0 * t) * exp(-20.0 * t))) * 0.5
        }
        
        bake(id: 2, duration: 0.05) { t in
            Float.random(in: -0.5...0.5) * Float(exp(-80.0 * t))
        }
        
        let bassFreqs = [41.2, 49.0, 55.0, 65.4]
        for (i, freq) in bassFreqs.enumerated() {
            bake(id: 3 + i, duration: 0.4) { t in
                var signal: Double = 0
                for harmonic in 1...5 {
                    let type = (harmonic % 2 == 0) ? 0.0 : 1.0
                    signal += (sin(Double(harmonic) * 2.0 * .pi * freq * t) * type) / Double(harmonic)
                }
                return Float(signal * exp(-2.0 * t) * 0.4)
            }
        }
        
        bake(id: 7, duration: 0.5) { t in
            var signal: Double = 0
            let fundamental = 220.0
            for harmonic in 1...10 {
                signal += sin(Double(harmonic) * 2.0 * .pi * fundamental * t) / Double(harmonic * harmonic)
            }
            return Float(signal * exp(-3.0 * t) * 0.5)
        }
    }
    
    func playPulse(beatIndex: Int) {
        guard !isPlaying else { return }
        
        startPlaybackIfNeeded()
        
        let state = getBeatState(index: beatIndex)
        
        if musicFile == nil {
            if state.kick, let buffer = prebakedBuffers[0] {
                synthNodes[0].scheduleBuffer(buffer, at: nil, options: .interrupts)
            }
            if state.snare, let buffer = prebakedBuffers[1] {
                synthNodes[1].scheduleBuffer(buffer, at: nil, options: .interrupts)
            }
            if state.hat, let buffer = prebakedBuffers[2] {
                synthNodes[2].scheduleBuffer(buffer, at: nil, options: .interrupts)
            }
        }
        
        if let note = state.bassNote, let buffer = prebakedBuffers[3 + note] {
            synthNodes[3].scheduleBuffer(buffer, at: nil, options: .interrupts)
        }
        
        if state.hornTrigger, let buffer = prebakedBuffers[7] {
            synthNodes[4].scheduleBuffer(buffer, at: nil, options: .interrupts)
        }
    }
    
    private func startPlaybackIfNeeded() {
        if isPlaying { return }
        
        synthNodes.forEach { $0.play() }
        
        if let file = musicFile {
            musicPlayer.scheduleFile(file, at: nil, completionHandler: nil)
            musicPlayer.play()
        }
        
        isPlaying = true
    }
    
    func stop() {
        synthNodes.forEach { $0.stop() }
        musicPlayer.stop()
        engine.stop()
        isPlaying = false
    }
    
    /// Indicates whether the audio engine is currently playing
    internal var isAudioPlaying: Bool {
        return isPlaying
    }
}

struct SeededRandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        state = UInt64(seed)
    }
    
    mutating func next() -> Double {
        state = state &* 1664525 &+ 1013904223
        return Double(state) / Double(UInt64.max)
    }
}