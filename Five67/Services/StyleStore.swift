import Foundation
import Observation

/// App-wide dance-style mode. Scopes both the feed (which videos appear in the
/// immersive stack) and the Library pane (which videos/moves appear in lists).
///
/// `activeStyle == nil` means "All" — no filtering. Persisted per-device to
/// UserDefaults so the chosen mode survives relaunch.
@MainActor
@Observable final class StyleStore {
    private static let key = "styleStore.activeStyle"

    var activeStyle: DanceStyle? {
        didSet {
            guard oldValue != activeStyle else { return }
            UserDefaults.standard.set(activeStyle?.rawValue ?? "", forKey: Self.key)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? ""
        activeStyle = DanceStyle(rawValue: raw)
    }

    /// Chip label: the active style's name, or "All" when unfiltered.
    var label: String { activeStyle?.label ?? "All" }

    /// True when the video belongs in the current mode. Untagged videos only
    /// appear in "All".
    func matches(_ video: Video) -> Bool {
        guard let activeStyle else { return true }
        return video.style == activeStyle
    }
}
