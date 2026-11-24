import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AVFoundation

public struct ContentView: View {
    @State private var tracks: [AudioTrack] = []
    @State private var currentMode: MergeMode = .overlap // Default to user's requested Overlap mode
    @State private var crossfadeDuration: Double = 1.0
    @State private var isCrossfadeEnabled: Bool = true
    @State private var zoomLevel: Double = 30.0 // Pixels per second
    @State private var isExportSheetPresented: Bool = false
    @State private var isDragOver: Bool = false

    @StateObject private var playerController = AudioPlayerController()
    @StateObject private var exporter = AudioExporter()
    @State private var compositionResult: AudioCompositionResult? = nil

    private let colorHues: [Double] = [0.58, 0.78, 0.38, 0.08, 0.92, 0.48, 0.18, 0.68]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar Header
            headerToolbar

            Divider()

            // Main Workspace Content
            if tracks.isEmpty {
                emptyDropZone
            } else {
                VStack(spacing: 12) {
                    // Visual Multi-track Timeline View
                    TimelineView(
                        tracks: $tracks,
                        mode: currentMode,
                        totalDuration: compositionResult?.totalDuration ?? 0,
                        currentTime: playerController.currentTime,
                        zoomLevel: $zoomLevel,
                        onSeek: { sec in
                            playerController.seek(to: sec)
                        },
                        onUpdate: rebuildComposition
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Track List Area (Scrollable)
                    ScrollView(.vertical) {
                        VStack(spacing: 12) {
                            if currentMode == .sequential {
                                SequentialTrackListView(
                                    tracks: $tracks,
                                    crossfadeDuration: $crossfadeDuration,
                                    isCrossfadeEnabled: $isCrossfadeEnabled,
                                    onUpdate: rebuildComposition
                                )
                            } else {
                                overlapTrackListView
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }

            Spacer(minLength: 0)

            Divider()

            // Bottom Master Transport Bar
            TransportBarView(
                playerController: playerController,
                zoomLevel: $zoomLevel,
                onSeek: { sec in
                    playerController.seek(to: sec)
                }
            )
            .padding(12)
        }
        .frame(minWidth: 840, minHeight: 620)
        .background(Color(NSColor.underPageBackgroundColor))
        .sheet(isPresented: $isExportSheetPresented) {
            ExportSheetView(
                compositionResult: compositionResult,
                exporter: exporter,
                onDismiss: { isExportSheetPresented = false }
            )
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onAppear {
            setupKeyboardMonitors()
        }
    }

    // Top Header Toolbar
    private var headerToolbar: some View {
        HStack(spacing: 16) {
            // Brand Logo & Name
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Music Mix Studio")
                        .font(.system(size: 15, weight: .bold))

                    Text("Timeline & Overlap Audio")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Mode Selector: Sequential vs Overlap
            Picker("Mode", selection: $currentMode) {
                ForEach(MergeMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            .onChange(of: currentMode) { _ in
                rebuildComposition()
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                // Add Files Button
                Button(action: openFileDialog) {
                    Label("Add Audio", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .help("Add audio files from Mac (Cmd+O)")

                // Add Demo Stems Button
                Button(action: addDemoAudio) {
                    Label("Demo Stems", systemImage: "music.note.list")
                }
                .buttonStyle(.bordered)
                .help("Load 3 multi-track demo stems (Beat, Bass, Melody) to test overlapping")

                if !tracks.isEmpty {
                    Button(action: clearAllTracks) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .help("Clear all tracks")
                }

                // Export Button
                Button(action: { isExportSheetPresented = true }) {
                    Label("Export Merged", systemImage: "square.and.arrow.up.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(tracks.isEmpty)
                .help("Export merged audio file (Cmd+E)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // Empty State Drop Zone (Clideo Style)
    private var emptyDropZone: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 6) {
                Text("Merge & Overlap Audio Files")
                    .font(.system(size: 20, weight: .bold))

                Text("Drag and drop audio files here, or click to browse")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Text("Supports MP3, WAV, M4A, AAC, FLAC, AIFF")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            HStack(spacing: 12) {
                Button(action: openFileDialog) {
                    Label("Choose Files", systemImage: "folder")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button(action: addDemoAudio) {
                    Label("Load Multi-Track Demo", systemImage: "sparkles")
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragOver ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .padding(24)
        )
    }

    // Overlap Mode Track List
    private var overlapTrackListView: some View {
        VStack(spacing: 12) {
            // Overlap helper actions bar
            HStack(spacing: 10) {
                Text("Timeline Alignment:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Button("Align All to 0s") {
                    for i in tracks.indices { tracks[i].offsetTime = 0.0 }
                    rebuildComposition()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10))

                Button("Cascade (2s step)") {
                    for i in tracks.indices { tracks[i].offsetTime = Double(i) * 2.0 }
                    rebuildComposition()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10))

                Button("Cascade (4s step)") {
                    for i in tracks.indices { tracks[i].offsetTime = Double(i) * 4.0 }
                    rebuildComposition()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10))

                Button("Snap Sequential") {
                    var cursor = 0.0
                    for i in tracks.indices {
                        tracks[i].offsetTime = cursor
                        cursor += tracks[i].trimmedDuration
                    }
                    rebuildComposition()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10))

                Spacer()

                Text("\(tracks.count) overlapping tracks")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            // Individual Track Rows
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                TrackRowView(
                    track: $tracks[index],
                    index: index,
                    totalCount: tracks.count,
                    mode: .overlap,
                    onMoveUp: {
                        guard index > 0 else { return }
                        tracks.swapAt(index, index - 1)
                        rebuildComposition()
                    },
                    onMoveDown: {
                        guard index < tracks.count - 1 else { return }
                        tracks.swapAt(index, index + 1)
                        rebuildComposition()
                    },
                    onDelete: {
                        tracks.remove(at: index)
                        rebuildComposition()
                    },
                    onUpdate: rebuildComposition
                )
            }
        }
    }

    // Load Files Dialog
    private func openFileDialog() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = [
            .audio,
            .mp3,
            .wav,
            .aiff,
            UTType("com.apple.coreaudio-format") ?? .audio,
            UTType("public.aac-audio") ?? .audio
        ]

        openPanel.begin { response in
            if response == .OK {
                loadAudioURLs(openPanel.urls)
            }
        }
    }

    // Add Demo Melodic Tracks
    private func addDemoAudio() {
        let demoURLs = DemoAudioGenerator.generateDemoStems()
        loadAudioURLs(demoURLs, isDemo: true)
    }

    // Process & Append Audio URLs
    private func loadAudioURLs(_ urls: [URL], isDemo: Bool = false) {
        var newTracks: [AudioTrack] = []

        for (idx, url) in urls.enumerated() {
            let asset = AVURLAsset(url: url)
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            let safeDuration = (durationSeconds.isNaN || durationSeconds.isInfinite) ? 10.0 : durationSeconds

            let colorHue = colorHues[(tracks.count + idx) % colorHues.count]
            let ext = url.pathExtension.uppercased()

            // In overlap mode, stagger new demo tracks slightly for an instant overlapping experience
            let initialOffset: Double
            if isDemo {
                initialOffset = Double(idx) * 2.0 // Drums at 0s, Bass at 2s, Melody at 4s!
            } else {
                initialOffset = 0.0
            }

            var track = AudioTrack(
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                originalDuration: safeDuration,
                trimStart: 0.0,
                trimEnd: safeDuration,
                offsetTime: initialOffset,
                volume: 1.0,
                fadeInDuration: isDemo && idx > 0 ? 1.0 : 0.0,
                fadeOutDuration: isDemo ? 1.5 : 0.0,
                colorHue: colorHue,
                fileFormat: ext.isEmpty ? "AUDIO" : ext
            )

            // Extract waveform in background
            WaveformGenerator.generateWaveform(url: url) { samples in
                if let trackIdx = self.tracks.firstIndex(where: { $0.id == track.id }) {
                    self.tracks[trackIdx].waveformSamples = samples
                }
            }

            newTracks.append(track)
        }

        tracks.append(contentsOf: newTracks)
        rebuildComposition()
    }

    // Rebuild AVComposition & reload Player
    private func rebuildComposition() {
        guard !tracks.isEmpty else {
            compositionResult = nil
            playerController.loadComposition(result: nil)
            return
        }

        let result = AudioCompositionBuilder.build(
            tracks: tracks,
            mode: currentMode,
            crossfadeDuration: isCrossfadeEnabled ? crossfadeDuration : 0.0
        )

        self.compositionResult = result
        playerController.loadComposition(result: result)
    }

    private func clearAllTracks() {
        playerController.pause()
        tracks.removeAll()
        compositionResult = nil
        playerController.loadComposition(result: nil)
    }

    // Handle Drag & Drop
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    if let directURL = item as? URL {
                        DispatchQueue.main.async { self.loadAudioURLs([directURL]) }
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.loadAudioURLs([url])
                }
            }
        }
    }

    // Global Spacebar shortcut for Play/Pause
    private func setupKeyboardMonitors() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Spacebar keyCode is 49
            if event.keyCode == 49 && !(NSApp.keyWindow?.firstResponder is NSText) {
                self.playerController.togglePlay()
                return nil
            }
            return event
        }
    }
}
