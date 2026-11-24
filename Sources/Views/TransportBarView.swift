import SwiftUI

public struct TransportBarView: View {
    @ObservedObject var playerController: AudioPlayerController
    @Binding var zoomLevel: Double
    let onSeek: (Double) -> Void

    public var body: some View {
        HStack(spacing: 16) {
            // Transport Controls: Rewind & Play/Pause
            HStack(spacing: 8) {
                Button(action: { playerController.rewind() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
                .help("Rewind to start (Home)")

                Button(action: { playerController.togglePlay() }) {
                    Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.35), radius: 4, x: 0, y: 2)
                .help("Play / Pause (Space)")

                Button(action: { playerController.isLooping.toggle() }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 13, weight: playerController.isLooping ? .bold : .regular))
                        .foregroundColor(playerController.isLooping ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(playerController.isLooping ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.15))
                .cornerRadius(6)
                .help("Toggle Loop Playback")
            }

            // Timecode Display: Current / Total
            HStack(spacing: 4) {
                Text(TimeFormatter.format(seconds: playerController.currentTime))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)

                Text("/")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text(TimeFormatter.format(seconds: playerController.totalDuration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 130)

            // Master Playhead Scrubber Slider
            Slider(
                value: Binding(
                    get: { playerController.currentTime },
                    set: { newVal in
                        playerController.seek(to: newVal)
                    }
                ),
                in: 0.0...max(0.1, playerController.totalDuration)
            )
            .accentColor(.red)

            // Master Volume Control
            HStack(spacing: 6) {
                Image(systemName: playerController.masterVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Slider(value: $playerController.masterVolume, in: 0.0...1.0)
                    .frame(width: 80)
            }
            .help("Master Output Volume")

            Divider().frame(height: 20)

            // Timeline Zoom Controls
            HStack(spacing: 4) {
                Button(action: { zoomLevel = max(10.0, zoomLevel - 5.0) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(4)
                .help("Zoom out timeline")

                Slider(value: $zoomLevel, in: 10.0...100.0)
                    .frame(width: 70)

                Button(action: { zoomLevel = min(100.0, zoomLevel + 5.0) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(4)
                .help("Zoom in timeline")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -1)
        )
    }
}
