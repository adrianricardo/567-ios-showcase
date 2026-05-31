import SwiftUI

/// App-wide semantic color tokens. Pairs with `Spacing` — one place owns the
/// "what color means what" decisions so call sites read intentionally.
///
/// ## Two color contexts
/// The app draws chrome in two fundamentally different contexts, and color
/// must be handled differently in each:
///
/// 1. **Over-video / immersive chrome** — controls overlaid directly on a
///    video (feed rail, hero top bar, the feed's empty-state CTA). These are
///    *always* light-on-dark for legibility over arbitrary video frames and do
///    NOT adapt to system light/dark. Hardcoded `.white` / `Color.black` is
///    correct here.
/// 2. **System-adaptive chrome** — surfaces that are NOT over video (lists,
///    buttons, backgrounds, the move list below the hero). These MUST use
///    semantic/adaptive colors (`Color(.systemBackground)`, `Color.primary`,
///    `Color.secondary`, system fills) and must NEVER hardcode `.white` or
///    `Color.black`, or they break in one appearance.
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

    /// Adaptive fill for a *secondary* button or quiet "add"/affordance chip on
    /// system chrome (e.g. the secondary "Import from Files" button, the
    /// "Add name" chip on a move row). Reads as a calm, recessive surface in
    /// both light and dark — pair with a `Color.primary` (or accent) label.
    static let secondaryChipFill: Color = Color(.tertiarySystemFill)
}
