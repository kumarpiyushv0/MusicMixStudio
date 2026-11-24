import Foundation
import SwiftUI

public struct AudioTrack: Identifiable, Equatable {
    public let id: UUID
    public var url: URL
    public var name: String
    public var originalDuration: Double
    public var trimStart: Double
    public var trimEnd: Double
    public var offsetTime: Double // Start position on timeline in Overlap Mode (seconds)
    public var volume: Double // 0.0 to 2.0 (1.0 = 100%)
    public var isMuted: Bool
    public var isSoloed: Bool
    public var fadeInDuration: Double // Seconds
    public var fadeOutDuration: Double // Seconds
    public var colorHue: Double // For unique visual track color
    public var waveformSamples: [Float] // Normalized amplitude samples (0.0 - 1.0)
    public var fileFormat: String
    public var fileSizeString: String

    public var trimmedDuration: Double {
        return max(0.01, trimEnd - trimStart)
    }

    public var effectiveEndOnTimeline: Double {
        return offsetTime + trimmedDuration
    }

    public var trackColor: Color {
        return Color(hue: colorHue, saturation: 0.75, brightness: 0.95)
    }

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        originalDuration: Double = 0.0,
        trimStart: Double = 0.0,
        trimEnd: Double? = nil,
        offsetTime: Double = 0.0,
        volume: Double = 1.0,
        isMuted: Bool = false,
        isSoloed: Bool = false,
        fadeInDuration: Double = 0.0,
        fadeOutDuration: Double = 0.0,
        colorHue: Double = 0.55,
        waveformSamples: [Float] = [],
        fileFormat: String = "AUDIO",
        fileSizeString: String = ""
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.deletingPathExtension().lastPathComponent
        self.originalDuration = originalDuration
        self.trimStart = trimStart
        self.trimEnd = trimEnd ?? originalDuration
        self.offsetTime = offsetTime
        self.volume = volume
        self.isMuted = isMuted
        self.isSoloed = isSoloed
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.colorHue = colorHue
        self.waveformSamples = waveformSamples
        self.fileFormat = fileFormat.uppercased()
        self.fileSizeString = fileSizeString
    }

    public static func == (lhs: AudioTrack, rhs: AudioTrack) -> Bool {
        return lhs.id == rhs.id &&
               lhs.url == rhs.url &&
               lhs.name == rhs.name &&
               lhs.originalDuration == rhs.originalDuration &&
               lhs.trimStart == rhs.trimStart &&
               lhs.trimEnd == rhs.trimEnd &&
               lhs.offsetTime == rhs.offsetTime &&
               lhs.volume == rhs.volume &&
               lhs.isMuted == rhs.isMuted &&
               lhs.isSoloed == rhs.isSoloed &&
               lhs.fadeInDuration == rhs.fadeInDuration &&
               lhs.fadeOutDuration == rhs.fadeOutDuration &&
               lhs.waveformSamples.count == rhs.waveformSamples.count
    }
}
