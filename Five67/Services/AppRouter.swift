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
    /// Changes whenever a Library selection should receive focus after routing
    /// to Feed. The selected object still travels through `pendingFeedSelection`.
    var feedFocusRequestID: UUID?
    /// Replaced for every Add button or Library import action so the Feed can
    /// consume a request even when it is mounted during a tab transition.
    var addVideoRequestID: UUID?
    /// True while the Feed needs the Add button hidden (coach beats, editor).
    var hidesBottomChrome = false
    /// The Feed's currently active video — used by Library to highlight now-playing.
    var currentFeedVideoID: UUID?
    /// The Feed's currently active move — used by Library to highlight now-playing.
    var currentFeedMoveID: UUID?

    /// Onboarding's single completion route. Lands on the Feed with the seed
    /// result selected and looping, through the same path Library selection uses.
    func showFeedAfterOnboarding(_ selection: FeedSelection?) {
        guard let selection else {
            selectedTab = .feed
            return
        }
        showInFeed(selection)
    }

    func showInFeed(_ selection: FeedSelection) {
        pendingFeedSelection = selection
        selectedTab = .feed
        feedFocusRequestID = UUID()
    }

    func requestAddVideo() {
        selectedTab = .feed
        addVideoRequestID = UUID()
    }
}
