import SwiftUI

public struct SequentialTrackListView: View {
    @Binding var tracks: [AudioTrack]
    @Binding var crossfadeDuration: Double
    @Binding var isCrossfadeEnabled: Bool
    let onUpdate: () -> Void

    public var body: some View {
        VStack(spacing: 12) {
            // Clideo-style Crossfade Settings Bar
            HStack(spacing: 16) {
                Toggle(isOn: $isCrossfadeEnabled) {
                    Label("Crossfade Transitions", systemImage: "waveform.badge.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                }
                .toggleStyle(.checkbox)
                .onChange(of: isCrossfadeEnabled) { _ in onUpdate() }

                if isCrossfadeEnabled {
                    HStack(spacing: 8) {
                        Text("Duration:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Slider(
                            value: $crossfadeDuration,
                            in: 0.5...5.0,
                            step: 0.5,
                            onEditingChanged: { isEditing in
                                if !isEditing { onUpdate() }
                            }
                        )
                        .frame(width: 120)

                        Text(String(format: "%.1fs", crossfadeDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 40, alignment: .leading)
                    }
                }

                Spacer()

                Text("\(tracks.count) \(tracks.count == 1 ? "track" : "tracks") joined in order")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            // List of Tracks
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                VStack(spacing: 4) {
                    TrackRowView(
                        track: $tracks[index],
                        index: index,
                        totalCount: tracks.count,
                        mode: .sequential,
                        onMoveUp: {
                            guard index > 0 else { return }
                            tracks.swapAt(index, index - 1)
                            onUpdate()
                        },
                        onMoveDown: {
                            guard index < tracks.count - 1 else { return }
                            tracks.swapAt(index, index + 1)
                            onUpdate()
                        },
                        onDelete: {
                            tracks.remove(at: index)
                            onUpdate()
                        },
                        onUpdate: onUpdate
                    )

                    // Visual Crossfade connector between items
                    if index < tracks.count - 1 {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)

                            if isCrossfadeEnabled {
                                Label("Crossfade \(String(format: "%.1fs", crossfadeDuration))", systemImage: "bolt.horizontal.fill")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(10)
                            } else {
                                Text("Next track")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}
