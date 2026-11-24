import Foundation
import AVFoundation

public struct AudioCompositionResult {
    public let composition: AVMutableComposition
    public let audioMix: AVAudioMix?
    public let totalDuration: Double
}

public struct AudioCompositionBuilder {
    public static func build(
        tracks: [AudioTrack],
        mode: MergeMode,
        crossfadeDuration: Double = 1.0
    ) -> AudioCompositionResult? {
        guard !tracks.isEmpty else { return nil }

        let composition = AVMutableComposition()
        let audioMix = AVMutableAudioMix()
        var inputParametersList: [AVMutableAudioMixInputParameters] = []

        switch mode {
        case .sequential:
            buildSequential(
                tracks: tracks,
                crossfadeDuration: crossfadeDuration,
                into: composition,
                inputParameters: &inputParametersList
            )
        case .overlap:
            buildOverlap(
                tracks: tracks,
                into: composition,
                inputParameters: &inputParametersList
            )
        }

        audioMix.inputParameters = inputParametersList
        let totalDuration = max(0.1, CMTimeGetSeconds(composition.duration))

        return AudioCompositionResult(
            composition: composition,
            audioMix: inputParametersList.isEmpty ? nil : audioMix,
            totalDuration: totalDuration
        )
    }

    private static func buildSequential(
        tracks: [AudioTrack],
        crossfadeDuration: Double,
        into composition: AVMutableComposition,
        inputParameters: inout [AVMutableAudioMixInputParameters]
    ) {
        guard let compTrackA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compTrackB = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return
        }

        let compTracks = [compTrackA, compTrackB]
        let paramsA = AVMutableAudioMixInputParameters(track: compTrackA)
        let paramsB = AVMutableAudioMixInputParameters(track: compTrackB)
        let params = [paramsA, paramsB]

        var currentCursor = CMTime.zero

        for (index, track) in tracks.enumerated() {
            let asset = AVURLAsset(url: track.url)
            guard let assetTrack = asset.tracks(withMediaType: .audio).first else { continue }

            let duration = max(0.1, track.trimmedDuration)
            let trimStart = CMTime(seconds: track.trimStart, preferredTimescale: 600)
            let trimDuration = CMTime(seconds: duration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: trimStart, duration: trimDuration)

            let compTrackIndex = index % 2
            let currentCompTrack = compTracks[compTrackIndex]
            let currentParams = params[compTrackIndex]

            let effectiveCrossfade = (index > 0 && crossfadeDuration > 0.05) ? min(crossfadeDuration, duration * 0.45) : 0.0

            if effectiveCrossfade > 0.05 {
                let crossfadeCMTime = CMTime(seconds: effectiveCrossfade, preferredTimescale: 600)
                currentCursor = CMTimeSubtract(currentCursor, crossfadeCMTime)
            }

            let insertTime = currentCursor

            do {
                try currentCompTrack.insertTimeRange(timeRange, of: assetTrack, at: insertTime)
            } catch {
                print("Error inserting track \(track.name): \(error)")
                continue
            }

            let trackVol = Float(track.isMuted ? 0.0 : track.volume)

            if effectiveCrossfade > 0.05 {
                let prevCompIndex = (index - 1) % 2
                let prevParams = params[prevCompIndex]
                let crossfadeCM = CMTime(seconds: effectiveCrossfade, preferredTimescale: 600)
                let prevFadeRange = CMTimeRange(start: insertTime, duration: crossfadeCM)
                let prevVol = Float(tracks[index - 1].isMuted ? 0.0 : tracks[index - 1].volume)

                // Ramp down previous track
                prevParams.setVolumeRamp(fromStartVolume: prevVol, toEndVolume: 0.0, timeRange: prevFadeRange)
                // Ramp up current track
                currentParams.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: trackVol, timeRange: prevFadeRange)
            } else {
                currentParams.setVolume(trackVol, at: insertTime)
            }

            currentCursor = CMTimeAdd(insertTime, trimDuration)
        }

        inputParameters.append(paramsA)
        inputParameters.append(paramsB)
    }

    private static func buildOverlap(
        tracks: [AudioTrack],
        into composition: AVMutableComposition,
        inputParameters: inout [AVMutableAudioMixInputParameters]
    ) {
        let hasSoloedTrack = tracks.contains { $0.isSoloed }

        for track in tracks {
            let asset = AVURLAsset(url: track.url)
            guard let assetTrack = asset.tracks(withMediaType: .audio).first else { continue }
            guard let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }

            let duration = max(0.1, track.trimmedDuration)
            let trimStart = CMTime(seconds: track.trimStart, preferredTimescale: 600)
            let trimDuration = CMTime(seconds: duration, preferredTimescale: 600)
            let sourceRange = CMTimeRange(start: trimStart, duration: trimDuration)

            let startTime = CMTime(seconds: max(0.0, track.offsetTime), preferredTimescale: 600)

            do {
                try compTrack.insertTimeRange(sourceRange, of: assetTrack, at: startTime)
            } catch {
                print("Error inserting overlapping track \(track.name): \(error)")
                continue
            }

            let params = AVMutableAudioMixInputParameters(track: compTrack)

            // Determine volume based on Solo / Mute states
            let effectiveVolume: Float
            if hasSoloedTrack {
                effectiveVolume = track.isSoloed ? Float(track.volume) : 0.0
            } else if track.isMuted {
                effectiveVolume = 0.0
            } else {
                effectiveVolume = Float(track.volume)
            }

            let hasFadeIn = track.fadeInDuration > 0.05 && track.fadeInDuration < duration
            let hasFadeOut = track.fadeOutDuration > 0.05 && track.fadeOutDuration < duration

            if hasFadeIn {
                let fadeInCM = CMTime(seconds: track.fadeInDuration, preferredTimescale: 600)
                let fadeInRange = CMTimeRange(start: startTime, duration: fadeInCM)
                params.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: effectiveVolume, timeRange: fadeInRange)
            }

            if hasFadeOut {
                let fadeOutCM = CMTime(seconds: track.fadeOutDuration, preferredTimescale: 600)
                let fadeOutStart = CMTimeSubtract(CMTimeAdd(startTime, trimDuration), fadeOutCM)
                let fadeOutRange = CMTimeRange(start: fadeOutStart, duration: fadeOutCM)
                let startVol = hasFadeIn && (track.fadeInDuration >= (duration - track.fadeOutDuration)) ? 0.0 : effectiveVolume
                params.setVolumeRamp(fromStartVolume: startVol, toEndVolume: 0.0, timeRange: fadeOutRange)
            }

            if !hasFadeIn && !hasFadeOut {
                params.setVolume(effectiveVolume, at: startTime)
            }

            inputParameters.append(params)
        }
    }
}
