import Foundation
import AVFoundation

public struct WaveformGenerator {
    public static func generateWaveform(url: URL, targetSamples: Int = 100, completion: @escaping ([Float]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            guard let track = asset.tracks(withMediaType: .audio).first else {
                let fallback = generateFallbackWaveform(count: targetSamples)
                DispatchQueue.main.async { completion(fallback) }
                return
            }

            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

            guard let reader = try? AVAssetReader(asset: asset) else {
                let fallback = generateFallbackWaveform(count: targetSamples)
                DispatchQueue.main.async { completion(fallback) }
                return
            }

            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                let fallback = generateFallbackWaveform(count: targetSamples)
                DispatchQueue.main.async { completion(fallback) }
                return
            }
            reader.add(output)
            reader.startReading()

            var rawAverages: [Float] = []
            var currentChunkSum: Float = 0.0
            var currentChunkCount = 0

            while reader.status == .reading {
                guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
                guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

                var length = 0
                var dataPointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

                if let ptr = dataPointer {
                    let numInt16 = length / 2
                    let int16Ptr = ptr.withMemoryRebound(to: Int16.self, capacity: numInt16) { $0 }
                    for i in stride(from: 0, to: numInt16, by: 4) { // Subsample for speed
                        let absVal = abs(Float(int16Ptr[i]) / 32768.0)
                        currentChunkSum += absVal
                        currentChunkCount += 1
                        if currentChunkCount >= 1000 {
                            rawAverages.append(currentChunkSum / Float(currentChunkCount))
                            currentChunkSum = 0
                            currentChunkCount = 0
                        }
                    }
                }
            }

            if rawAverages.isEmpty {
                let fallback = generateFallbackWaveform(count: targetSamples)
                DispatchQueue.main.async { completion(fallback) }
                return
            }

            // Downsample or interpolate to exact targetSamples
            var result: [Float] = []
            let step = Double(rawAverages.count) / Double(targetSamples)
            var maxVal: Float = 0.001

            for s in 0..<targetSamples {
                let idx = min(rawAverages.count - 1, Int(Double(s) * step))
                let val = rawAverages[idx]
                if val > maxVal { maxVal = val }
                result.append(val)
            }

            // Normalize so peaks fill nicely
            let normalized = result.map { val -> Float in
                let n = (val / maxVal)
                return max(0.12, min(1.0, n))
            }

            DispatchQueue.main.async {
                completion(normalized)
            }
        }
    }

    private static func generateFallbackWaveform(count: Int) -> [Float] {
        return (0..<count).map { i in
            let phase = Double(i) * 0.15
            let v = Float(abs(sin(phase) * 0.5 + sin(phase * 2.3) * 0.3 + 0.2))
            return max(0.15, min(0.9, v))
        }
    }
}
