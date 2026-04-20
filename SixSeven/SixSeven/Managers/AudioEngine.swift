import AVFoundation
import UIKit

/// Procedural audio engine using AVAudioEngine.
/// Generates phonk-style BGM, reactive low-pass filter, snap SFX, and haptics.
final class AudioEngine: ObservableObject {
    private var engine = AVAudioEngine()
    private var mixer: AVAudioMixerNode { engine.mainMixerNode }

    // BGM sequencer
    private var bgmTimer: DispatchSourceTimer?
    private var bgmStep: Int = 0
    private let bpm: Double = 140
    private var stepDuration: TimeInterval { 60.0 / bpm / 4.0 }

    // Low-pass filter node
    private var filterNode: AVAudioUnitEQ?
    private var isMuffled = false

    // Haptics
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    @Published var isMuted = false

    // MARK: - Setup

    func setup() {
        configureAudioSession()
        setupFilterNode()

        do {
            try engine.start()
        } catch {
            print("[AudioEngine] Failed to start: \(error)")
        }

        impactHeavy.prepare()
        impactMedium.prepare()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[AudioEngine] Audio session error: \(error)")
        }
    }

    private func setupFilterNode() {
        let eq = AVAudioUnitEQ(numberOfBands: 1)
        let band = eq.bands[0]
        band.filterType = .lowPass
        band.frequency = 20000 // fully open
        band.bandwidth = 1.0
        band.bypass = false

        engine.attach(eq)
        // Insert EQ between mixer and output
        let format = mixer.outputFormat(forBus: 0)
        engine.connect(mixer, to: eq, format: format)
        engine.connect(eq, to: engine.outputNode, format: format)

        filterNode = eq
    }

    func shutdown() {
        stopBGM()
        engine.stop()
    }

    // MARK: - Mute

    func toggleMute() {
        isMuted.toggle()
        mixer.outputVolume = isMuted ? 0 : 1
    }

    // MARK: - Underwater Filter

    func setMuffled(_ muffled: Bool) {
        guard let band = filterNode?.bands.first, muffled != isMuffled else { return }
        isMuffled = muffled
        band.frequency = muffled ? 400 : 20000
    }

    // MARK: - BGM (Phonk Sequencer)

    func startBGM() {
        guard bgmTimer == nil else { return }
        bgmStep = 0

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(
            deadline: .now(),
            repeating: stepDuration,
            leeway: .milliseconds(1)
        )
        timer.setEventHandler { [weak self] in
            self?.scheduleBGMStep()
        }
        timer.resume()
        bgmTimer = timer
    }

    func stopBGM() {
        bgmTimer?.cancel()
        bgmTimer = nil
    }

    // Patterns: 16 steps = 1 bar
    private let kickPattern:  [Bool] = [true,false,false,false, true,false,false,false, true,false,false,false, true,false,false,true]
    private let hihatPattern: [Bool] = [false,false,true,false, false,false,true,false, false,false,true,true, false,false,true,false]
    private let subPattern:   [Bool] = [true,false,false,false, true,false,false,false, true,false,false,false, true,false,false,false]
    private let clapPattern:  [Bool] = [false,false,false,false, true,false,false,false, false,false,false,false, true,false,false,false]

    private func scheduleBGMStep() {
        let idx = bgmStep % 16
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        if kickPattern[idx] { playKick(format: format) }
        if hihatPattern[idx] { playHihat(format: format) }
        if subPattern[idx] { playSub(format: format) }
        if clapPattern[idx] { playClap(format: format) }

        bgmStep += 1
    }

    // MARK: - Drum Synthesis

    private func playKick(format: AVAudioFormat) {
        let sampleRate = format.sampleRate
        let duration = 0.15
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Pitch sweep 150Hz → 40Hz
            let freq = 150.0 * pow(40.0 / 150.0, t / duration)
            let phase = 2.0 * .pi * freq * t
            let envelope = max(0, 1.0 - t / duration)
            data[i] = Float(sin(phase) * envelope * 0.7)
        }

        playBuffer(buffer, volume: 0.25)
    }

    private func playHihat(format: AVAudioFormat) {
        let sampleRate = format.sampleRate
        let duration = 0.04
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)
            // Filtered noise (just use high-frequency noise)
            let noise = Float.random(in: -1...1)
            data[i] = noise * Float(envelope) * 0.3
        }

        playBuffer(buffer, volume: 0.2)
    }

    private func playSub(format: AVAudioFormat) {
        let sampleRate = format.sampleRate
        let duration = stepDuration * 2
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)
            data[i] = Float(sin(2.0 * .pi * 55.0 * t) * envelope * 0.5)
        }

        playBuffer(buffer, volume: 0.2)
    }

    private func playClap(format: AVAudioFormat) {
        let sampleRate = format.sampleRate
        let duration = 0.06
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)
            let noise = Float.random(in: -1...1)
            // Bandpass-ish: multiply noise by a resonant sine
            let resonance = Float(sin(2.0 * .pi * 1200.0 * t))
            data[i] = noise * resonance * Float(envelope) * 0.3
        }

        playBuffer(buffer, volume: 0.2)
    }

    // MARK: - SFX

    /// Heavy bass-boosted slam on successful count
    func playSnapSFX() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let sampleRate = format.sampleRate

        // Bass hit
        let duration = 0.25
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let freq = 200.0 * pow(30.0 / 200.0, t / duration)
            let envelope = max(0, 1.0 - t / duration)
            let bass = sin(2.0 * .pi * freq * t) * envelope
            let noise = Double(Float.random(in: -1...1)) * max(0, 1.0 - t / 0.08) * 0.3
            let click = sin(2.0 * .pi * 800.0 * t) * max(0, 1.0 - t / 0.02) * 0.3
            data[i] = Float((bass + noise + click) * 0.8)
        }

        playBuffer(buffer, volume: 0.6)
    }

    /// Countdown beep
    func playCountdownBeep(isGo: Bool) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let sampleRate = format.sampleRate
        let duration = isGo ? 0.4 : 0.15
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return }

        let freq = isGo ? 1047.0 : 880.0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)
            data[i] = Float(sin(2.0 * .pi * freq * t) * envelope * 0.5)
        }

        playBuffer(buffer, volume: 0.5)
    }

    /// Victory fanfare
    func playVictorySFX() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let sampleRate = format.sampleRate
        let duration = 0.8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return }

        let notes: [(freq: Double, start: Double)] = [
            (784, 0), (659, 0.12), (523, 0.24), (1047, 0.45)
        ]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = 0.0
            for note in notes {
                let noteT = t - note.start
                if noteT >= 0 && noteT < 0.35 {
                    let env = max(0, 1.0 - noteT / 0.35)
                    sample += sin(2.0 * .pi * note.freq * noteT) * env * 0.3
                }
            }
            data[i] = Float(sample)
        }

        playBuffer(buffer, volume: 0.5)
    }

    // MARK: - Haptics

    func triggerCountHaptic() {
        impactHeavy.impactOccurred(intensity: 1.0)
    }

    func triggerHalfwayHaptic() {
        impactMedium.impactOccurred(intensity: 0.6)
    }

    // MARK: - Buffer Playback

    private func playBuffer(_ buffer: AVAudioPCMBuffer, volume: Float) {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: mixer, format: buffer.format)
        player.volume = volume

        player.scheduleBuffer(buffer) {
            DispatchQueue.main.async {
                self.engine.detach(player)
            }
        }
        player.play()
    }
}
