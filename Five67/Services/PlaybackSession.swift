import Foundation
import Observation

/// App-wide playback preferences. Persisted to UserDefaults so a user who
/// muted last session opens muted next session.
///
/// `isMuted` is the single source of truth for audio on/off across every
/// surface (feed, editor). Initial default is muted so first launch is quiet.
@MainActor
@Observable final class PlaybackSession {
    private static let mutedKey = "playbackSession.isMuted"

    var isMuted: Bool {
        didSet {
            guard oldValue != isMuted else { return }
            UserDefaults.standard.set(isMuted, forKey: Self.mutedKey)
        }
    }

    init() {
        // `bool(forKey:)` returns false for a missing key. We want the *first*
        // launch (no key written yet) to be muted, so check presence first.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.mutedKey) == nil {
            self.isMuted = true
            defaults.set(true, forKey: Self.mutedKey)
        } else {
            self.isMuted = defaults.bool(forKey: Self.mutedKey)
        }
    }
}
