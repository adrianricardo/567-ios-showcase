import Foundation
import SwiftData

@Model final class Video {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var localFilename: String
    var sourceAssetID: String?
    var importedAt: Date
    var recordedAt: Date?
    var duration: TimeInterval
    /// True only for the bundled onboarding demo clip. Demo rows are excluded
    /// from free-video counts, free-style claims, legacy grandfathering, and
    /// library exports. Added in schema V5; existing rows migrate as `false`.
    var isDemo: Bool = false
    var style: Style?
    @Relationship(deleteRule: .cascade) var moves: [Move] = []

    init(
        id: UUID = UUID(),
        displayName: String,
        localFilename: String,
        sourceAssetID: String? = nil,
        importedAt: Date = Date(),
        recordedAt: Date? = nil,
        duration: TimeInterval,
        isDemo: Bool = false,
        style: Style? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.localFilename = localFilename
        self.sourceAssetID = sourceAssetID
        self.importedAt = importedAt
        self.recordedAt = recordedAt
        self.duration = duration
        self.isDemo = isDemo
        self.style = style
    }
}

extension Video {
    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("videos")
            .appendingPathComponent(localFilename)
    }

    var movesSorted: [Move] {
        moves.sorted { $0.time < $1.time }
    }
}

extension Sequence where Element == Video {
    /// Personal (non-demo) videos. The single canonical filter — never scatter
    /// `!isDemo` across views. Free-video cap and free-style logic count these.
    var personalVideos: [Video] {
        filter { !$0.isDemo }
    }

    var personalVideoCount: Int {
        reduce(into: 0) { count, video in
            if !video.isDemo { count += 1 }
        }
    }
}
