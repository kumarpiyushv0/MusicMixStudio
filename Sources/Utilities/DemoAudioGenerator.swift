import Foundation
import AVFoundation

public struct DemoAudioGenerator {
    public static func generateDemoStems() -> [URL] {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AudioMergerDemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let beatURL = tempDir.appendingPathComponent("1_Rhythm_Drums.wav")
        let bassURL = tempDir.appendingPathComponent("2_Groove_Bass.wav")
        let melodyURL = tempDir.appendingPathComponent("3_Synth_Melody.wav")

        generateDrumTrack(url: beatURL, duration: 12.0)
        generateBassTrack(url: bassURL, duration: 12.0)
        generateMelodyTrack(url: melodyURL, duration: 12.0)

        return [beatURL, bassURL, melodyURL]
    }

    private static func generateDrumTrack(url: URL, duration: Double) {
        let sampleRate: Double = 44100.0
        let totalSamples = Int(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let audioFile = try? AVAudioFile(forWriting: url, settings: format.settings),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(totalSamples)
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]

        let bpm = 120.0
        let beatInterval = 60.0 / bpm // 0.5s per beat
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let beatTime = t.truncatingRemainder(dividingBy: beatInterval)
            var sample: Float = 0.0

            // Kick drum on beats 0 and 2
            let measureBeat = Int(t / beatInterval) % 4
            if measureBeat == 0 || measureBeat == 2 {
                if beatTime < 0.18 {
                    let freq = 130.0 * exp(-beatTime * 25.0) + 45.0
                    sample += Float(sin(2.0 * .pi * freq * beatTime) * exp(-beatTime * 14.0) * 0.7)
                }
            }
            // Snare / clap on beats 1 and 3
            if measureBeat == 1 || measureBeat == 3 {
                if beatTime < 0.22 {
                    let noise = Float((Double.random(in: -1...1))) * Float(exp(-beatTime * 18.0)) * 0.4
                    let tone = Float(sin(2.0 * .pi * 200.0 * beatTime) * exp(-beatTime * 20.0) * 0.3)
                    sample += noise + tone
                }
            }
            // Hi-hat every eighth note (every 0.25s)
            let eighthTime = t.truncatingRemainder(dividingBy: beatInterval / 2.0)
            if eighthTime < 0.05 {
                let hihat = Float(Double.random(in: -1...1)) * Float(exp(-eighthTime * 60.0)) * 0.18
                sample += hihat
            }

            left[i] = sample
            right[i] = sample
        }
        try? audioFile.write(from: buffer)
    }

    private static func generateBassTrack(url: URL, duration: Double) {
        let sampleRate: Double = 44100.0
        let totalSamples = Int(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let audioFile = try? AVAudioFile(forWriting: url, settings: format.settings),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(totalSamples)
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]

        let bassNotes: [Double] = [65.41, 65.41, 77.78, 87.31, 98.00, 87.31, 77.78, 65.41] // C2, Eb2, F2, G2
        let noteDuration = 0.5

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let noteIdx = Int(t / noteDuration) % bassNotes.count
            let noteTime = t.truncatingRemainder(dividingBy: noteDuration)
            let freq = bassNotes[noteIdx]

            var env = exp(-noteTime * 3.5)
            if noteTime < 0.02 { env *= (noteTime / 0.02) }

            // Warm sub bass + subtle harmonic
            let sample = Float((sin(2.0 * .pi * freq * noteTime) * 0.5 +
                                sin(2.0 * .pi * freq * 2.0 * noteTime) * 0.2) * env * 0.6)
            left[i] = sample
            right[i] = sample
        }
        try? audioFile.write(from: buffer)
    }

    private static func generateMelodyTrack(url: URL, duration: Double) {
        let sampleRate: Double = 44100.0
        let totalSamples = Int(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let audioFile = try? AVAudioFile(forWriting: url, settings: format.settings),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(totalSamples)
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]

        // Arpeggiated chime notes (C4, Eb4, G4, Bb4, C5, Bb4, G4, Eb4)
        let chimeNotes: [Double] = [261.63, 311.13, 392.00, 466.16, 523.25, 466.16, 392.00, 311.13]
        let stepDuration = 0.25

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let noteIdx = Int(t / stepDuration) % chimeNotes.count
            let noteTime = t.truncatingRemainder(dividingBy: stepDuration)
            let freq = chimeNotes[noteIdx]

            var env = exp(-noteTime * 7.0)
            if noteTime < 0.01 { env *= (noteTime / 0.01) }

            let sample = Float((sin(2.0 * .pi * freq * noteTime) * 0.4 +
                                sin(2.0 * .pi * freq * 3.0 * noteTime) * 0.1) * env * 0.5)
            // Stereo panning effect
            let pan = Float(sin(2.0 * .pi * 0.5 * t))
            left[i] = sample * (1.0 - pan * 0.3)
            right[i] = sample * (1.0 + pan * 0.3)
        }
        try? audioFile.write(from: buffer)
    }
}
