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
    @Relationship(deleteRule: .cascade) var moves: [Move] = []

    init(
        id: UUID = UUID(),
        displayName: String,
        localFilename: String,
        sourceAssetID: String? = nil,
        importedAt: Date = Date(),
        recordedAt: Date? = nil,
        duration: TimeInterval
    ) {
        self.id = id
        self.displayName = displayName
        self.localFilename = localFilename
        self.sourceAssetID = sourceAssetID
        self.importedAt = importedAt
        self.recordedAt = recordedAt
        self.duration = duration
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
