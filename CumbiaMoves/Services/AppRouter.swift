import Foundation
import Observation

enum AppTab: Hashable {
    case moves
    case library
}

/// Cross-tab navigation glue. Lives in the environment so deep views can
/// switch tabs (e.g. VideoDetail's "Done" action jumping to Moves).
@MainActor
@Observable final class AppRouter {
    var selectedTab: AppTab = .library
}
