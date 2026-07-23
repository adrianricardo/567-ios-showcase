import Foundation
import SwiftData

enum VideoImportPersistence {
    @discardableResult
    @MainActor
    static func insertVideo(
        from result: VideoImportResult,
        in context: ModelContext
    ) -> Video {
        let video = Video(
            displayName: result.displayName,
            localFilename: result.filename,
            sourceAssetID: result.sourceID,
            recordedAt: result.recordedAt,
            duration: result.duration
        )
        context.insert(video)
        prewarmThumbnails(for: video)
        return video
    }

    @MainActor
    private static func prewarmThumbnails(for video: Video) {
        let videoURL = video.fileURL
        let videoID = video.id
        let duration = video.duration
        Task.detached(priority: .utility) {
            _ = await ThumbnailService.shared.thumbnails(
                for: videoURL,
                videoID: videoID,
                count: 10,
                height: 36,
                duration: duration
            )
        }
    }
}
