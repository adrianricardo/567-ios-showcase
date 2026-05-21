import Foundation
import Observation

/// App-lifetime playback preferences. Resets each cold launch.
///
/// `isMuted` defaults to `true` on launch so videos start quiet. Once the user
/// unmutes, the preference carries across video switches and pages — but it is
/// not persisted to disk, so the next launch starts muted again.
@MainActor
@Observable final class PlaybackSession {
    var isMuted: Bool = true
}
