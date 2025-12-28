import Foundation
import AVFoundation
import SwiftUI

/// Actor-based audio engine for thread-safe operations (Swift 5.9+)
@globalActor
actor AudioEngineActor {
    static let shared = AudioEngineActor()
    
    private var engine: AVAudioEngine
    private var mixer: AVAudioMixerNode
    private var reverb: AVAudioUnitReverb
    private var delay: AVAudioUnitDelay
    private var synthNodes: [AVAudioPlayerNode] = []
    private var musicPlayer: AVAudioPlayerNode
    private var isPlaying = false
    private var prebakedBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var musicFile: AVAudioFile?
    
    private init() {
        self.engine = AVAudioEngine()
        self.mixer = AVAudioMixerNode()
        self.reverb = AVAudioUnitReverb()
        self.delay = AVAudioUnitDelay()
        self.musicPlayer = AVAudioPlayerNode()
        
        setupEngine()
        prebakeInstruments()
    }
    
    /// Thread-safe audio engine setup
    private func setupEngine() async {
        do {
            engine.attach(mixer)
            engine.attach(reverb)
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = GameConstants.reverbWetDryMix
            
            engine.attach(delay)
            delay.delayTime = GameConstants.delayTime
            delay.feedback = GameConstants.delayFeedback
            delay.wetDryMix = GameConstants.delayWetDryMix
            
            let format = AVAudioFormat(standardFormatWithSampleRate: GameConstants.sampleRate, channels: 2)!
            
            engine.connect(mixer, to: delay, format: format)
            engine.connect(delay, to: reverb, format: format)
            engine.connect(reverb, to: engine.mainMixerNode, format: format)
            
            // Create synth nodes
            synthNodes = (0..<8).map { _ in AVAudioPlayerNode() }
            for node in synthNodes {
                engine.attach(node)
                engine.connect(node, to: mixer, format: format)
            }
            
            engine.attach(musicPlayer)
            engine.connect(musicPlayer, to: mixer, format: format)
            
            try engine.start()
        } catch {
            await Logger.shared.log("Audio engine setup failed: \(error)", level: .error)
        }
    }
    
    /// Thread-safe beat state generation
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
    
    /// Thread-safe audio pulse playback
    func playPulse(beatIndex: Int) async {
        guard !isPlaying else { return }
        
        await startPlaybackIfNeeded()
        
        let state = getBeatState(index: beatIndex)
        
        if musicFile == nil {
            if state.kick, let buffer = prebakedBuffers[InstrumentID.kick.rawValue] {
                synthNodes[InstrumentID.kick.rawValue].scheduleBuffer(buffer, at: nil, options: .interrupts)
            }
            if state.snare, let buffer = prebakedBuffers[InstrumentID.snare.rawValue] {
                synthNodes[InstrumentID.snare.rawValue].scheduleBuffer(buffer, at: nil, options: .interrupts)
            }
            if state.hat, let buffer = prebakedBuffers[InstrumentID.hat.rawValue] {
                synthNodes[InstrumentID.hat.rawValue].scheduleBuffer(buffer, at: nil, options: .interrupts)
            }
        }
        
        if let note = state.bassNote, let buffer = prebakedBuffers[3 + note] {
            synthNodes[3 + note].scheduleBuffer(buffer, at: nil, options: .interrupts)
        }
        
        if state.hornTrigger, let buffer = prebakedBuffers[InstrumentID.horn.rawValue] {
            synthNodes[InstrumentID.horn.rawValue].scheduleBuffer(buffer, at: nil, options: .interrupts)
        }
    }
    
    /// Thread-safe playback startup
    private func startPlaybackIfNeeded() async {
        guard !isPlaying else { return }
        
        synthNodes.forEach { $0.play() }
        
        if let file = musicFile {
            musicPlayer.scheduleFile(file, at: nil, completionHandler: nil)
            musicPlayer.play()
        }
        
        isPlaying = true
        await Logger.shared.log("Audio playback started", level: .info)
    }
    
    /// Thread-safe engine stop
    func stop() async {
        synthNodes.forEach { $0.stop() }
        musicPlayer.stop()
        engine.stop()
        isPlaying = false
        await Logger.shared.log("Audio engine stopped", level: .info)
    }
    
    /// Thread-safe state check
    var isAudioPlaying: Bool {
        return isPlaying
    }
    
    /// Thread-safe music file loading
    func loadAudioFile(_ fileName: String?) async throws {
        guard let fileName = fileName else { return }
        
        let extensions = GameConstants.FileExtensions.audio
        
        for ext in extensions {
            if let url = Bundle.main.url(forResource: fileName, withExtension: ext) {
                let file = try AVAudioFile(forReading: url)
                musicFile = file
                await Logger.shared.log("Loaded audio file: \(fileName).\(ext)", level: .info)
                return
            }
        }
        
        throw GameError.audioFileNotFound(fileName)
    }
    
    /// Pre-bake instruments with async processing
    private func prebakeInstruments() async {
        let format = AVAudioFormat(standardFormatWithSampleRate: GameConstants.sampleRate, channels: 2)!
        let sampleRate = GameConstants.sampleRate
        
        for instrument in InstrumentID.allCases {
            let buffer = await generateInstrumentBuffer(
                for: instrument,
                format: format,
                sampleRate: sampleRate
            )
            prebakedBuffers[instrument.rawValue] = buffer
        }
        
        await Logger.shared.log("Pre-baked \(prebakedBuffers.count) instrument buffers", level: .info)
    }
    
    /// Generate individual instrument buffer
    private func generateInstrumentBuffer(
        for instrument: InstrumentID,
        format: AVAudioFormat,
        sampleRate: Double
    ) async -> AVAudioPCMBuffer {
        
        let frameCount = AVAudioFrameCount(sampleRate * instrument.duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return AVAudioPCMBuffer()
        }
        
        buffer.frameLength = frameCount
        
        for channel in 0..<Int(format.channelCount) {
            let data = buffer.floatChannelData![channel]
            
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                data[i] = generateSampleValue(for: instrument, at: t)
            }
        }
        
        return buffer
    }
    
    /// Generate sample values for different instruments
    private func generateSampleValue(for instrument: InstrumentID, at time: Double) -> Float {
        switch instrument {
        case .kick:
            return Float(sin(2.0 * .pi * (60.0 * exp(-10.0 * time)) * time) * exp(-5.0 * time))
            
        case .snare:
            let noise = Float.random(in: -1...1) * Float(exp(-30.0 * time))
            let tone = Float(sin(2.0 * .pi * 200.0 * time) * exp(-20.0 * time))
            return (noise + tone) * 0.5
            
        case .hat:
            return Float.random(in: -0.5...0.5) * Float(exp(-80.0 * time))
            
        case .bass1, .bass2, .bass3, .bass4:
            let bassFreqs = [41.2, 49.0, 55.0, 65.4]
            let freq = bassFreqs[instrument.rawValue - InstrumentID.bass1.rawValue]
            var signal: Double = 0
            
            for harmonic in 1...5 {
                let type = (harmonic % 2 == 0) ? 0.0 : 1.0
                signal += (sin(Double(harmonic) * 2.0 * .pi * freq * time) * type) / Double(harmonic)
            }
            
            return Float(signal * exp(-2.0 * time) * 0.4)
            
        case .horn:
            var signal: Double = 0
            let fundamental = 220.0
            
            for harmonic in 1...10 {
                signal += sin(Double(harmonic) * 2.0 * .pi * fundamental * time) / Double(harmonic * harmonic)
            }
            
            return Float(signal * exp(-3.0 * time) * 0.5)
        }
    }
}