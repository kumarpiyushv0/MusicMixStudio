import SwiftUI
import AppKit

public struct ExportSheetView: View {
    let compositionResult: AudioCompositionResult?
    @ObservedObject var exporter: AudioExporter
    let onDismiss: () -> Void

    @State private var selectedFormat: ExportFormat = .m4a
    @State private var outputFileName: String = "Merged_Audio"
    @State private var exportedFileURL: URL? = nil
    @State private var errorMessage: String? = nil

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Merged Audio")
                        .font(.system(size: 18, weight: .bold))

                    Text("Total duration: \(TimeFormatter.format(seconds: compositionResult?.totalDuration ?? 0))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Output File Name
            VStack(alignment: .leading, spacing: 6) {
                Text("File Name:")
                    .font(.system(size: 12, weight: .medium))

                HStack {
                    TextField("File Name", text: $outputFileName)
                        .textFieldStyle(.roundedBorder)

                    Text(".\(selectedFormat.fileExtension)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            // Format Selection Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Format:")
                    .font(.system(size: 12, weight: .medium))

                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedFormat.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            // Progress or Error status
            if exporter.isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exporter.progress, total: 1.0)
                        .progressViewStyle(.linear)

                    Text(exporter.statusMessage)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let exportedURL = exportedFileURL {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))

                        Text("Audio exported successfully!")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    HStack(spacing: 12) {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([exportedURL])
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Done") {
                            onDismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            } else if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            Divider()

            // Footer Buttons
            HStack {
                if exporter.isExporting {
                    Button("Cancel") {
                        exporter.cancel()
                    }
                    .buttonStyle(.bordered)
                } else if exportedFileURL == nil {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Export Audio...") {
                        promptSaveAndExport()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(compositionResult == nil)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func promptSaveAndExport() {
        guard let result = compositionResult else { return }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "\(outputFileName).\(selectedFormat.fileExtension)"
        savePanel.allowedContentTypes = [selectedFormat == .m4a ? .mpeg4Audio : (selectedFormat == .wav ? .wav : .aiff)]

        savePanel.begin { response in
            if response == .OK, let targetURL = savePanel.url {
                self.errorMessage = nil
                self.exportedFileURL = nil

                self.exporter.export(
                    result: result,
                    format: self.selectedFormat,
                    outputURL: targetURL
                ) { exportResult in
                    switch exportResult {
                    case .success(let finalURL):
                        self.exportedFileURL = finalURL
                    case .failure(let err):
                        self.errorMessage = err.localizedDescription
                    }
                }
            }
        }
    }
}
