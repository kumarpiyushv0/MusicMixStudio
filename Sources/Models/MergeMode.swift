import Foundation

public enum MergeMode: String, CaseIterable, Identifiable {
    case sequential = "Sequential Join"
    case overlap = "Overlap Timeline"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .sequential:
            return "arrow.right.arrow.left"
        case .overlap:
            return "square.3.layers.3d.down.right"
        }
    }

    public var description: String {
        switch self {
        case .sequential:
            return "Join tracks sequentially in order, with optional crossfades between clips."
        case .overlap:
            return "Multi-track editor: overlap audio tracks freely, shift offsets, and mix together."
        }
    }
}

public enum ExportFormat: String, CaseIterable, Identifiable {
    case m4a = "M4A"
    case wav = "WAV"
    case aiff = "AIFF"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .m4a: return "m4a"
        case .wav: return "wav"
        case .aiff: return "aiff"
        }
    }

    public var mimeType: String {
        switch self {
        case .m4a: return "audio/mp4"
        case .wav: return "audio/wav"
        case .aiff: return "audio/aiff"
        }
    }

    public var description: String {
        switch self {
        case .m4a: return "AAC compressed (256 kbps) - Best for sharing & mobile"
        case .wav: return "Linear PCM Lossless (16-bit 44.1kHz) - Studio quality"
        case .aiff: return "Apple Audio Interchange Lossless (16-bit 44.1kHz)"
        }
    }
}
