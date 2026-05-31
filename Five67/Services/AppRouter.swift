import Foundation
import Observation

struct FeedSelection: Equatable {
    let videoID: UUID
    let moveID: UUID?
}

enum AppTab: Hashable {
    case feed
    case library
    case style
    /// Detached add-video control rendered via `Tab(role: .search)`. Never stays
    /// selected — selecting it triggers an import request and restores the prior tab.
    case add
}

/// Cross-tab coordinator. Lives in the environment so any tab can route back to
/// the feed, hand it a pending selection, or request an import.
@MainActor
@Observable final class AppRouter {
    var selectedTab: AppTab = .feed
    /// Set by Library when a video/move is tapped; consumed + cleared by the Feed.
    var pendingFeedSelection: FeedSelection?
    /// Set by the Add button or Library import actions; consumed + cleared by the Feed.
    var addVideoRequested = false
    /// True while the Feed needs the Add button hidden (coach beats, editor).
    var hidesBottomChrome = false
    /// The Feed's currently active video — used by Library to highlight now-playing.
    var currentFeedVideoID: UUID?
    /// The Feed's currently active move — used by Library to highlight now-playing.
    var currentFeedMoveID: UUID?
}
