import Foundation
import Observation

enum AppTab: Hashable {
    case feed
    case library
}

/// Drives the global Library/Feed switch. Lives in the environment so deep
/// views can route back (e.g. VideoDetail's "Done" jumps to Feed).
@MainActor
@Observable final class AppRouter {
    var selectedTab: AppTab = .feed
}
