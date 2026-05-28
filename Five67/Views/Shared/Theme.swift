import SwiftUI

/// App-wide semantic color tokens. Pairs with `Spacing` — one place owns the
/// "what color means what" decisions so call sites read intentionally.
///
/// Only tokens with a clear semantic role belong here. Raw accent / background
/// usage (`Color.accentColor`, `Color(.systemBackground)`) stays inline.
enum Theme {
    /// Row tint when a list row represents the currently active/selected item
    /// (active move in the editor, active video in the library).
    static let rowActiveBackground: Color = Color(.tertiarySystemFill)

    /// Foreground tint for the "now playing" affordance (e.g. the waveform
    /// glyph next to the active video row in the library).
    static let nowPlayingIndicator: Color = Color.accentColor
}
