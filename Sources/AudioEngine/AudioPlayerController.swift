import Foundation
import AVFoundation
import Combine

public class AudioPlayerController: ObservableObject {
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var totalDuration: Double = 0.0
    @Published public var isLooping: Bool = false
    @Published public var masterVolume: Double = 1.0 {
        didSet { player?.volume = Float(masterVolume) }
    }

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var endObserverToken: Any?
    private var isSeeking: Bool = false

    public init() {
        self.player = AVPlayer()
        setupTimeObserver()
    }

    deinit {
        cleanup()
    }

    public func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let endToken = endObserverToken {
            NotificationCenter.default.removeObserver(endToken)
            endObserverToken = nil
        }
        player?.pause()
        player = nil
    }

    private func setupTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(value: 1, timescale: 30) // 30 fps
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            let seconds = CMTimeGetSeconds(time)
            if !seconds.isNaN && !seconds.isInfinite {
                self.currentTime = seconds
            }
        }
    }

    public func loadComposition(result: AudioCompositionResult?, autoPlay: Bool = false) {
        guard let result = result else {
            player?.pause()
            isPlaying = false
            totalDuration = 0.0
            currentTime = 0.0
            return
        }

        let wasPlaying = isPlaying || autoPlay
        let previousTime = currentTime

        if let endToken = endObserverToken {
            NotificationCenter.default.removeObserver(endToken)
            endObserverToken = nil
        }

        let playerItem = AVPlayerItem(asset: result.composition)
        if let mix = result.audioMix {
            playerItem.audioMix = mix
        }

        self.totalDuration = result.totalDuration

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            setupTimeObserver()
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        player?.volume = Float(masterVolume)

        // Observe playback completion
        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.isLooping {
                self.seek(to: 0.0)
                self.player?.play()
            } else {
                self.isPlaying = false
                self.seek(to: 0.0)
            }
        }

        // Restore position if within new bounds
        if previousTime < result.totalDuration && previousTime > 0.1 {
            seek(to: previousTime)
        } else {
            seek(to: 0.0)
        }

        if wasPlaying {
            player?.play()
            isPlaying = true
        }
    }

    public func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard totalDuration > 0 else { return }
        if currentTime >= totalDuration - 0.05 {
            seek(to: 0.0)
        }
        player?.play()
        isPlaying = true
    }

    public func pause() {
        player?.pause()
        isPlaying = false
    }

    public func rewind() {
        seek(to: 0.0)
    }

    public func seek(to seconds: Double) {
        let clamped = max(0.0, min(totalDuration, seconds))
        currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func beginScrubbing() {
        isSeeking = true
    }

    public func endScrubbing(to seconds: Double) {
        isSeeking = false
        seek(to: seconds)
    }
}
