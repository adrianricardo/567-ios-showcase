import Foundation
import SwiftData

/// The single owner of video deletion. Library and the editor both route here so
/// file removal, thumbnail-cache cleanup, SwiftData deletion, and the
/// personal-video recount that clears a stale free-style claim can never drift
/// apart between the two surfaces.
@MainActor
enum VideoDeletionService {
    static func delete(
        _ video: Video,
        in context: ModelContext,
        unlockStore: UnlockStore
    ) {
        let videoID = video.id
        let fileURL = video.fileURL

        Task { await ThumbnailService.shared.clearCache(for: videoID) }
        try? FileManager.default.removeItem(at: fileURL)
        context.delete(video)

        // Recount from the store rather than a caller's `@Query` snapshot, which
        // has not observed this deletion yet. The just-deleted row is filtered
        // by id so the result does not depend on when SwiftData flushes.
        let remaining = (try? context.fetch(FetchDescriptor<Video>())) ?? []
        unlockStore.recountPersonalVideos(
            remaining.filter { $0.id != videoID }.count
        )

        Haptics.medium()
    }

    /// Exact named-move impact, shared by every surface that confirms a delete.
    static func namedMoveImpact(for video: Video) -> String {
        let namedMoveCount = video.moves.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        if namedMoveCount == 0 {
            return "No named moves will be removed."
        }
        return "This also removes \(namedMoveCount) named \(namedMoveCount == 1 ? "move" : "moves") saved in this video."
    }
}
