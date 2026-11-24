import SwiftUI
import AVFoundation

public struct TrackRowView: View {
    @Binding var track: AudioTrack
    let index: Int
    let totalCount: Int
    let mode: MergeMode
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onUpdate: () -> Void

    public var body: some View {
        VStack(spacing: 8) {
            // Header Row: Index, Name, Format Badge, Move, Delete
            HStack(spacing: 10) {
                // Track Index Circle with track color
                ZStack {
                    Circle()
                        .fill(track.trackColor.opacity(0.25))
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(track.trackColor)
                }

                // Track Name & Format
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(track.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        Text(track.fileFormat)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.18))
                            .cornerRadius(4)
                            .foregroundColor(.secondary)
                    }

                    Text("Duration: \(TimeFormatter.formatDurationShort(seconds: track.trimmedDuration)) (orig: \(TimeFormatter.formatDurationShort(seconds: track.originalDuration)))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Sequential reordering buttons
                if mode == .sequential {
                    HStack(spacing: 2) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == totalCount - 1)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                }

                // Mute & Solo Buttons
                HStack(spacing: 4) {
                    Button(action: {
                        track.isMuted.toggle()
                        onUpdate()
                    }) {
                        Text("M")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(track.isMuted ? Color.red.opacity(0.8) : Color.secondary.opacity(0.15))
                            .foregroundColor(track.isMuted ? .white : .primary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Mute track")

                    Button(action: {
                        track.isSoloed.toggle()
                        onUpdate()
                    }) {
                        Text("S")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(track.isSoloed ? Color.yellow.opacity(0.85) : Color.secondary.opacity(0.15))
                            .foregroundColor(track.isSoloed ? .black : .primary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Solo track")
                }

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Remove track")
            }

            // Visual Waveform Preview
            WaveformBarView(samples: track.waveformSamples, color: track.trackColor, trimStart: track.trimStart, trimEnd: track.trimEnd, totalDuration: track.originalDuration)
                .frame(height: 38)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)

            // Trim Controls: Start & End Trim
            HStack(spacing: 12) {
                Label("Trim Start:", systemImage: "arrow.right.to.line")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Slider(
                    value: $track.trimStart,
                    in: 0.0...max(0.0, track.trimEnd - 0.2),
                    onEditingChanged: { isEditing in
                        if !isEditing { onUpdate() }
                    }
                )
                .accentColor(track.trackColor)

                Text(TimeFormatter.format(seconds: track.trimStart))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 55, alignment: .trailing)

                Divider().frame(height: 12)

                Label("Trim End:", systemImage: "arrow.left.to.line")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Slider(
                    value: $track.trimEnd,
                    in: min(track.originalDuration, track.trimStart + 0.2)...track.originalDuration,
                    onEditingChanged: { isEditing in
                        if !isEditing { onUpdate() }
                    }
                )
                .accentColor(track.trackColor)

                Text(TimeFormatter.format(seconds: track.trimEnd))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 55, alignment: .trailing)
            }

            // Controls Row: Volume & Mode-specific parameters
            HStack(spacing: 16) {
                // Volume Slider
                HStack(spacing: 6) {
                    Image(systemName: track.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Slider(
                        value: $track.volume,
                        in: 0.0...2.0,
                        onEditingChanged: { isEditing in
                            if !isEditing { onUpdate() }
                        }
                    )
                    .frame(width: 110)

                    Text("\(Int(track.volume * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 38, alignment: .leading)
                }

                // If Overlap Mode: Start Offset & Fade sliders
                if mode == .overlap {
                    Divider().frame(height: 16)

                    // Start Offset slider / controls
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                            .foregroundColor(track.trackColor)

                        Text("Offset:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Slider(
                            value: $track.offsetTime,
                            in: 0.0...120.0,
                            step: 0.25,
                            onEditingChanged: { isEditing in
                                if !isEditing { onUpdate() }
                            }
                        )
                        .accentColor(track.trackColor)
                        .frame(width: 100)

                        Text(TimeFormatter.format(seconds: track.offsetTime))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 55, alignment: .trailing)
                    }

                    Divider().frame(height: 16)

                    // Fade In & Fade Out
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("In:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Stepper(
                                value: $track.fadeInDuration,
                                in: 0.0...5.0,
                                step: 0.5,
                                onEditingChanged: { _ in onUpdate() }
                            ) {
                                Text("\(String(format: "%.1f", track.fadeInDuration))s")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }

                        HStack(spacing: 4) {
                            Text("Out:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Stepper(
                                value: $track.fadeOutDuration,
                                in: 0.0...5.0,
                                step: 0.5,
                                onEditingChanged: { _ in onUpdate() }
                            ) {
                                Text("\(String(format: "%.1f", track.fadeOutDuration))s")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(track.isSoloed ? Color.yellow.opacity(0.5) : track.trackColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// Waveform preview component
public struct WaveformBarView: View {
    let samples: [Float]
    let color: Color
    let trimStart: Double
    let trimEnd: Double
    let totalDuration: Double

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let barCount = max(1, samples.count)
            let barWidth = max(1.5, width / CGFloat(barCount) - 1.0)

            let startFrac = totalDuration > 0 ? CGFloat(trimStart / totalDuration) : 0
            let endFrac = totalDuration > 0 ? CGFloat(trimEnd / totalDuration) : 1

            ZStack(alignment: .leading) {
                // Waveform Bars
                HStack(alignment: .center, spacing: 1.0) {
                    ForEach(0..<samples.count, id: \.self) { idx in
                        let frac = CGFloat(idx) / CGFloat(barCount)
                        let isInsideTrim = frac >= startFrac && frac <= endFrac
                        let barHeight = max(3.0, CGFloat(samples[idx]) * height * 0.85)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(isInsideTrim ? color : Color.secondary.opacity(0.25))
                            .frame(width: barWidth, height: barHeight)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Left Dimmed Mask (trimmed out)
                if startFrac > 0.01 {
                    Rectangle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: width * startFrac)
                }

                // Right Dimmed Mask (trimmed out)
                if endFrac < 0.99 {
                    Rectangle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: width * (1.0 - endFrac))
                        .offset(x: width * endFrac)
                }
            }
        }
    }
}
