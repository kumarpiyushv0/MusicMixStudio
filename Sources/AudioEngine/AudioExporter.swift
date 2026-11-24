import Foundation
import AVFoundation

public class AudioExporter: ObservableObject {
    @Published public var isExporting: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = ""

    private var currentExportSession: AVAssetExportSession?
    private var isCancelled: Bool = false
    private var progressTimer: Timer?

    public init() {}

    public func export(
        result: AudioCompositionResult,
        format: ExportFormat,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        isExporting = true
        progress = 0.0
        isCancelled = false
        statusMessage = "Preparing \(format.rawValue) export..."

        // Remove existing file at destination
        try? FileManager.default.removeItem(at: outputURL)

        switch format {
        case .m4a:
            exportM4A(result: result, outputURL: outputURL, completion: completion)
        case .wav, .aiff:
            exportPCM(result: result, format: format, outputURL: outputURL, completion: completion)
        }
    }

    public func cancel() {
        isCancelled = true
        progressTimer?.invalidate()
        progressTimer = nil
        currentExportSession?.cancelExport()
        isExporting = false
        statusMessage = "Export cancelled"
    }

    private func exportM4A(
        result: AudioCompositionResult,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let session = AVAssetExportSession(
            asset: result.composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            finishWithError(NSError(domain: "AudioExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize AVAssetExportSession"]), completion: completion)
            return
        }

        self.currentExportSession = session
        session.outputURL = outputURL
        session.outputFileType = .m4a
        if let mix = result.audioMix {
            session.audioMix = mix
        }

        // Timer for progress polling
        DispatchQueue.main.async {
            self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let s = self.currentExportSession else { return }
                self.progress = Double(s.progress)
                self.statusMessage = String(format: "Rendering Audio... %d%%", Int(self.progress * 100))
            }
        }

        session.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                self?.progressTimer?.invalidate()
                self?.progressTimer = nil
                self?.isExporting = false

                if self?.isCancelled == true {
                    try? FileManager.default.removeItem(at: outputURL)
                    completion(.failure(NSError(domain: "AudioExporter", code: 99, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
                    return
                }

                switch session.status {
                case .completed:
                    self?.progress = 1.0
                    self?.statusMessage = "Export complete!"
                    completion(.success(outputURL))
                case .failed:
                    let err = session.error ?? NSError(domain: "AudioExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                    self?.statusMessage = "Export error: \(err.localizedDescription)"
                    completion(.failure(err))
                case .cancelled:
                    completion(.failure(NSError(domain: "AudioExporter", code: 99, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
                default:
                    completion(.failure(NSError(domain: "AudioExporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown export status"])))
                }
            }
        }
    }

    private func exportPCM(
        result: AudioCompositionResult,
        format: ExportFormat,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let fileType: AVFileType = (format == .wav) ? .wav : .aiff

                guard let reader = try? AVAssetReader(asset: result.composition) else {
                    throw NSError(domain: "AudioExporter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize AVAssetReader"])
                }

                let audioTracks = result.composition.tracks(withMediaType: .audio)
                guard !audioTracks.isEmpty else {
                    throw NSError(domain: "AudioExporter", code: 5, userInfo: [NSLocalizedDescriptionKey: "No audio tracks in composition"])
                }

                let readerOutputSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: (format == .aiff),
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]

                let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: readerOutputSettings)
                if let mix = result.audioMix {
                    readerOutput.audioMix = mix
                }
                readerOutput.alwaysCopiesSampleData = false

                guard reader.canAdd(readerOutput) else {
                    throw NSError(domain: "AudioExporter", code: 6, userInfo: [NSLocalizedDescriptionKey: "Cannot add audio mix reader output"])
                }
                reader.add(readerOutput)

                let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
                let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: readerOutputSettings)
                writerInput.expectsMediaDataInRealTime = false

                guard writer.canAdd(writerInput) else {
                    throw NSError(domain: "AudioExporter", code: 7, userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input"])
                }
                writer.add(writerInput)

                guard reader.startReading() else {
                    throw reader.error ?? NSError(domain: "AudioExporter", code: 8, userInfo: [NSLocalizedDescriptionKey: "Reader failed to start"])
                }
                guard writer.startWriting() else {
                    throw writer.error ?? NSError(domain: "AudioExporter", code: 9, userInfo: [NSLocalizedDescriptionKey: "Writer failed to start"])
                }

                writer.startSession(atSourceTime: .zero)

                let totalSeconds = max(0.1, result.totalDuration)
                var lastProgressUpdate: Date = Date()

                let writeQueue = DispatchQueue(label: "com.clideo.audiomerge.writer")
                writerInput.requestMediaDataWhenReady(on: writeQueue) {
                    while writerInput.isReadyForMoreMediaData {
                        if self.isCancelled {
                            reader.cancelReading()
                            writer.cancelWriting()
                            try? FileManager.default.removeItem(at: outputURL)
                            DispatchQueue.main.async {
                                self.isExporting = false
                                completion(.failure(NSError(domain: "AudioExporter", code: 99, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
                            }
                            return
                        }

                        if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            let currentSec = CMTimeGetSeconds(pts)
                            let currentProgress = min(0.99, max(0.0, currentSec / totalSeconds))

                            if Date().timeIntervalSince(lastProgressUpdate) > 0.08 {
                                lastProgressUpdate = Date()
                                DispatchQueue.main.async {
                                    self.progress = currentProgress
                                    self.statusMessage = String(format: "Rendering Lossless Audio... %d%%", Int(currentProgress * 100))
                                }
                            }

                            writerInput.append(sampleBuffer)
                        } else {
                            // Finished reading
                            writerInput.markAsFinished()
                            writer.finishWriting {
                                DispatchQueue.main.async {
                                    self.isExporting = false
                                    if writer.status == .completed {
                                        self.progress = 1.0
                                        self.statusMessage = "Export complete!"
                                        completion(.success(outputURL))
                                    } else {
                                        let err = writer.error ?? NSError(domain: "AudioExporter", code: 10, userInfo: [NSLocalizedDescriptionKey: "Writer failed"])
                                        self.statusMessage = "Export error: \(err.localizedDescription)"
                                        completion(.failure(err))
                                    }
                                }
                            }
                            break
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.finishWithError(error, completion: completion)
                }
            }
        }
    }

    private func finishWithError(_ error: Error, completion: @escaping (Result<URL, Error>) -> Void) {
        self.isExporting = false
        self.statusMessage = "Error: \(error.localizedDescription)"
        completion(.failure(error))
    }
}
