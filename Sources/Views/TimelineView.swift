import SwiftUI

public struct TimelineView: View {
    @Binding var tracks: [AudioTrack]
    let mode: MergeMode
    let totalDuration: Double
    let currentTime: Double
    @Binding var zoomLevel: Double // pixels per second (e.g. 15 to 80)
    let onSeek: (Double) -> Void
    let onUpdate: () -> Void

    @State private var draggingTrackId: UUID? = nil
    @State private var initialDragOffset: Double = 0.0

    public var body: some View {
        VStack(spacing: 0) {
            // Timeline Ruler
            TimeRulerView(
                totalDuration: max(5.0, totalDuration),
                pixelsPerSecond: zoomLevel,
                currentTime: currentTime,
                onSeek: onSeek
            )
            .frame(height: 28)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))

            Divider()

            // Scrollable Track Lanes
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    let timelineWidth = max(700.0, max(5.0, totalDuration) * zoomLevel + 120.0)

                    // Background Grid Lines
                    TimelineGrid(
                        totalDuration: max(5.0, totalDuration),
                        pixelsPerSecond: zoomLevel,
                        height: CGFloat(max(3, tracks.count)) * 48.0
                    )
                    .frame(width: timelineWidth)

                    // Track Lanes
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            TrackLaneView(
                                track: track,
                                index: index,
                                mode: mode,
                                pixelsPerSecond: zoomLevel,
                                onDragOffsetChanged: { newOffset in
                                    if let idx = tracks.firstIndex(where: { $0.id == track.id }) {
                                        tracks[idx].offsetTime = max(0.0, newOffset)
                                        onUpdate()
                                    }
                                }
                            )
                            .frame(height: 42)
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(width: timelineWidth, alignment: .leading)

                    // Red Playhead Line
                    let playheadX = CGFloat(currentTime * zoomLevel)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: CGFloat(max(3, tracks.count)) * 48.0 + 8.0)
                        .offset(x: playheadX)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 140, maxHeight: 280)
            .background(Color.black.opacity(0.3))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// Time Ruler Component
public struct TimeRulerView: View {
    let totalDuration: Double
    let pixelsPerSecond: Double
    let currentTime: Double
    let onSeek: (Double) -> Void

    public var body: some View {
        GeometryReader { geo in
            let rulerWidth = max(geo.size.width, totalDuration * pixelsPerSecond + 120.0)
            let stepSeconds: Double = pixelsPerSecond > 35 ? 1.0 : (pixelsPerSecond > 18 ? 2.0 : 5.0)

            ZStack(alignment: .leading) {
                // Background click for seeking
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let sec = max(0.0, min(totalDuration, Double(value.location.x) / pixelsPerSecond))
                                onSeek(sec)
                            }
                    )

                // Tick Marks & Timestamps
                ForEach(stride(from: 0.0, through: totalDuration + 5.0, by: stepSeconds).map { $0 }, id: \.self) { sec in
                    let x = CGFloat(sec * pixelsPerSecond)
                    let isMajor = Int(sec) % 5 == 0

                    VStack(alignment: .leading, spacing: 1) {
                        Rectangle()
                            .fill(Color.secondary.opacity(isMajor ? 0.6 : 0.3))
                            .frame(width: 1, height: isMajor ? 12 : 6)

                        if isMajor {
                            Text(TimeFormatter.formatDurationShort(seconds: sec))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .offset(x: x)
                }

                // Playhead Scrubber Triangle on Ruler
                let playheadX = CGFloat(currentTime * pixelsPerSecond)
                PlayheadMarker()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .offset(x: playheadX - 5, y: 16)
            }
            .frame(width: rulerWidth)
        }
    }
}

// Background Grid Lines
public struct TimelineGrid: View {
    let totalDuration: Double
    let pixelsPerSecond: Double
    let height: CGFloat

    public var body: some View {
        Canvas { context, size in
            let step = pixelsPerSecond > 25 ? 1.0 : 5.0
            for sec in stride(from: 0.0, through: totalDuration + 10.0, by: step) {
                let x = CGFloat(sec * pixelsPerSecond)
                let isMajor = Int(sec) % 5 == 0
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
                context.stroke(
                    path,
                    with: .color(Color.secondary.opacity(isMajor ? 0.15 : 0.06)),
                    lineWidth: 1
                )
            }
        }
        .frame(height: height)
    }
}

// Individual Track Lane
public struct TrackLaneView: View {
    let track: AudioTrack
    let index: Int
    let mode: MergeMode
    let pixelsPerSecond: Double
    let onDragOffsetChanged: (Double) -> Void

    @State private var dragStartOffset: Double = 0.0

    public var body: some View {
        GeometryReader { _ in
            let startX = CGFloat(track.offsetTime * pixelsPerSecond)
            let clipWidth = max(24.0, CGFloat(track.trimmedDuration * pixelsPerSecond))

            ZStack(alignment: .leading) {
                // Background Track Lane Slot
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.06))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Draggable Clip Block
                HStack(spacing: 6) {
                    // Track color tag
                    Rectangle()
                        .fill(track.trackColor)
                        .frame(width: 4)

                    // Track title & duration
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.name)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(.white)

                        Text("\(TimeFormatter.formatDurationShort(seconds: track.trimmedDuration)) @ \(TimeFormatter.format(seconds: track.offsetTime))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    if track.fadeInDuration > 0 || track.fadeOutDuration > 0 {
                        HStack(spacing: 2) {
                            if track.fadeInDuration > 0 {
                                Image(systemName: "waveform.path.badge.plus")
                                    .font(.system(size: 8))
                            }
                            if track.fadeOutDuration > 0 {
                                Image(systemName: "waveform.path.badge.minus")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 4)
                .frame(width: clipWidth, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(track.trackColor.opacity(0.75))
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .offset(x: startX)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if dragStartOffset == 0.0 && value.translation.width == 0 {
                                dragStartOffset = track.offsetTime
                            }
                            let deltaSeconds = Double(value.translation.width) / pixelsPerSecond
                            let newOffset = max(0.0, dragStartOffset + deltaSeconds)
                            onDragOffsetChanged(newOffset)
                        }
                        .onEnded { _ in
                            dragStartOffset = 0.0
                        }
                )
                .help("Drag to adjust start time: \(track.name)")
            }
        }
    }
}

// Marker Shape
public struct PlayheadMarker: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
