import Foundation
import Observation
import SwiftData

/// App-wide dance-style mode. Scopes both the feed (which videos appear in the
/// immersive stack) and the Library pane (which videos/moves appear in lists).
///
/// `activeStyle == nil` means "All" — no filtering. Persisted per-device to
/// UserDefaults (by `Style.id`) so the chosen mode survives relaunch.
@MainActor
@Observable final class StyleStore {
    private static let key = "styleStore.activeStyleID"

    var activeStyle: Style? {
        didSet {
            guard oldValue?.id != activeStyle?.id else { return }
            UserDefaults.standard.set(activeStyle?.id.uuidString ?? "", forKey: Self.key)
        }
    }

    init() {
        activeStyle = nil
    }

    /// Rehydrate `activeStyle` from the persisted UUID once a `ModelContext` is
    /// available. Idempotent — safe to call every time the root view appears.
    func rehydrateIfNeeded(in context: ModelContext) {
        guard activeStyle == nil else { return }
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? ""
        guard !raw.isEmpty, let id = UUID(uuidString: raw) else { return }
        let descriptor = FetchDescriptor<Style>(predicate: #Predicate { $0.id == id })
        if let style = try? context.fetch(descriptor).first {
            activeStyle = style
        }
    }

    /// Chip label: the active style's name, or "All" when unfiltered.
    var label: String { activeStyle?.name ?? "All" }

    /// True when the video belongs in the current mode. Untagged videos only
    /// appear in "All".
    func matches(_ video: Video) -> Bool {
        guard let activeStyle else { return true }
        return video.style?.id == activeStyle.id
    }
}
