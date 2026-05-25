import Foundation

/// A dance style a video can be tagged with. Stored on `Video`; all moves
/// inherit their parent video's style (per-move override is deferred).
enum DanceStyle: String, Codable, CaseIterable, Identifiable {
    case cumbia, salsa, bachata

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}
