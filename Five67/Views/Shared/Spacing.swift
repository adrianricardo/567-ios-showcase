import CoreGraphics

/// App-wide spacing scale. Soft 4pt grid — every common gap, inset, and
/// vertical rhythm value in the codebase has a named token here so call sites
/// read intentionally and one place owns the magic numbers.
///
/// Naming convention: `xs / sm / md / lg / xl …` for the core scale,
/// `*Plus` variants for the 2pt half-step between two anchors, then a small
/// set of semantic component tokens at the bottom (touch targets, button
/// heights, layout offsets that depend on screen chrome).
enum Spacing {
    /// 0pt — explicit zero, useful in `VStack(spacing: Spacing.none)`.
    static let none: CGFloat = 0
    /// 2pt — hairline.
    static let xxs: CGFloat = 2
    /// 4pt — tight inner gap.
    static let xs: CGFloat = 4
    /// 6pt — fine micro-gap.
    static let xsPlus: CGFloat = 6
    /// 8pt — base unit, small inner padding.
    static let sm: CGFloat = 8
    /// 10pt — between `sm` and `md`.
    static let smPlus: CGFloat = 10
    /// 12pt — default control-to-control gap.
    static let md: CGFloat = 12
    /// 14pt — between `md` and `lg`.
    static let mdPlus: CGFloat = 14
    /// 16pt — standard screen-edge inset.
    static let lg: CGFloat = 16
    /// 18pt — slightly looser than `lg`.
    static let lgPlus: CGFloat = 18
    /// 20pt — generous edge inset.
    static let xl: CGFloat = 20
    /// 24pt — section / group gap.
    static let xl2: CGFloat = 24
    /// 28pt — comfortable rhythm between blocks.
    static let xl3: CGFloat = 28
    /// 32pt — large gap.
    static let xl4: CGFloat = 32
    /// 40pt — hero / wide gap.
    static let xl5: CGFloat = 40
    /// 48pt — overlay / sheet inner padding.
    static let xl6: CGFloat = 48

    // MARK: - Component sizes
    /// 44pt — Apple HIG minimum tap target.
    static let touchTarget: CGFloat = 44
    /// 52pt — primary button height.
    static let primaryButtonHeight: CGFloat = 52
    /// 56pt — list row minimum height.
    static let rowMinHeight: CGFloat = 56

    // MARK: - Feed-screen layout
    /// Legacy offset kept for `VideoDetailView` centering (tab bar is hidden
    /// there, so this counteracts the empty area at the bottom of the editor).
    static let bottomBarTopOffset: CGFloat = 92
    /// Small visual gap between content and the bottom of the native tab bar
    /// safe-area inset. Used by panes and the feed CTA card.
    static let bottomBarClearance: CGFloat = 8
}
