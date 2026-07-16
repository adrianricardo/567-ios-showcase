import Foundation
import SwiftUI

/// A style's approved signal color. The raw RGB value keeps palette behavior
/// testable without comparing platform color objects.
struct StyleAccent: Equatable, Sendable {
    let name: String
    let rgb: UInt32

    var color: Color {
        StagePalette.color(rgb)
    }
}

/// Raw Quiet Stage values live beside their semantic SwiftUI tokens so
/// contrast can be locked with tests instead of judged only by screenshots.
enum StagePalette {
    static let background: UInt32 = 0x070707
    static let surface: UInt32 = 0x1B1B1B
    static let raisedSurface: UInt32 = 0x252525
    static let primary: UInt32 = 0xF7F3E9
    static let secondary: UInt32 = 0xB8B1A7
    static let actionSurface: UInt32 = 0xFFFDF7
    static let ink: UInt32 = 0x10100F

    static func color(_ rgb: UInt32) -> Color {
        Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    static func contrastRatio(_ first: UInt32, _ second: UInt32) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05)
            / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private static func relativeLuminance(_ rgb: UInt32) -> Double {
        let components = [16, 8, 0].map { shift -> Double in
            let value = Double((rgb >> shift) & 0xFF) / 255
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
    }
}

/// Small, hard-coded palette chosen to stay vivid and legible on the Quiet
/// Stage neutrals. Known styles keep their color; custom styles are assigned
/// deterministically from the same approved palette using their stable UUID.
enum StyleAccentPalette {
    static let salsa = StyleAccent(name: "Salsa coral", rgb: 0xFF6B4A)
    static let cumbia = StyleAccent(name: "Cumbia gold", rgb: 0xFFD166)
    static let bachata = StyleAccent(name: "Bachata rose", rgb: 0xFF9EB5)
    static let kizomba = StyleAccent(name: "Kizomba violet", rgb: 0xB7A0FF)
    static let zouk = StyleAccent(name: "Zouk cyan", rgb: 0x71D7E8)
    static let merengue = StyleAccent(name: "Merengue lime", rgb: 0xB8F05A)

    static let approved = [salsa, cumbia, bachata, kizomba, zouk, merengue]

    static func accent(forName name: String, id: UUID? = nil) -> StyleAccent? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "all", "other": nil
        case "salsa": salsa
        case "cumbia": cumbia
        case "bachata": bachata
        case "kizomba": kizomba
        case "zouk": zouk
        case "merengue": merengue
        default:
            id.map { approved[stablePaletteIndex(for: $0)] }
        }
    }

    private static func stablePaletteIndex(for id: UUID) -> Int {
        withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(into: 0) { result, byte in
                result = (result &* 31 &+ Int(byte)) % approved.count
            }
        }
    }
}

/// App-wide semantic color tokens. Pairs with `Spacing` — one place owns the
/// "what color means what" decisions so call sites read intentionally.
///
/// ## Color contexts
/// The app draws in three contexts, and color must be handled differently in
/// each:
///
/// 1. **Over-video / immersive chrome** — controls overlaid directly on a
///    video (feed rail, hero top bar, the feed's empty-state CTA). These are
///    *always* light-on-dark for legibility over arbitrary video frames and do
///    NOT adapt to system light/dark. Hardcoded `.white` / `Color.black` is
///    correct here.
/// 2. **Quiet Stage content** — the deliberate dark brand canvas used by core
///    Library and onboarding surfaces. These use the `stage*` semantic tokens
///    below and are intentionally appearance-independent.
/// 3. **System utility chrome** — settings, sheets, exports, and similar
///    surfaces use adaptive colors (`Color(.systemBackground)`,
///    `Color.primary`, `Color.secondary`, and system fills).
///
/// Only tokens with a clear semantic role belong here. Raw accent / background
/// usage (`Color.accentColor`, `Color(.systemBackground)`) stays inline.
enum Theme {
    // MARK: - Quiet Stage

    /// Flat neutral surfaces for content. Liquid Glass remains reserved for
    /// native navigation and floating chrome, not card decoration.
    static let stageBackground = StagePalette.color(StagePalette.background)
    static let stageSurface = StagePalette.color(StagePalette.surface)
    static let stageRaisedSurface = StagePalette.color(StagePalette.raisedSurface)
    static let stagePrimary = StagePalette.color(StagePalette.primary)
    static let stageSecondary = StagePalette.color(StagePalette.secondary)
    /// Warm white is reserved for the screen's one primary action. Selection
    /// remains on `stageSurface` and uses a dedicated glyph instead.
    static let stageActionSurface = StagePalette.color(StagePalette.actionSurface)
    static let stageInk = StagePalette.color(StagePalette.ink)
    static let stageStroke = Color.white.opacity(0.09)

    /// Adaptive fill for a *secondary* button or quiet "add"/affordance chip on
    /// system chrome (e.g. the secondary "Import from Files" button, the
    /// "Add name" chip on a move row). Reads as a calm, recessive surface in
    /// both light and dark — pair with a `Color.primary` (or accent) label.
    static let secondaryChipFill: Color = Color(.tertiarySystemFill)
}

// MARK: - Quiet Stage primitives

/// Centralizes the Warm Stage primary-action recipe so future token changes
/// do not require editing individual screens.
struct StagePrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(isEnabled ? Theme.stageInk : Theme.stageSecondary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                isEnabled ? Theme.stageActionSurface : Theme.stageRaisedSurface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

/// The sole visible selection cue for a Quiet Stage selectable row. Its fixed
/// frame prevents the row's content from shifting when the checkmark appears.
struct StageSelectionCheckmark: View {
    let isSelected: Bool
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.black))
                    .foregroundStyle(accent)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.82).combined(with: .opacity)
                    )
            }
        }
        .frame(width: 28, height: 28)
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0.03),
            value: isSelected
        )
        .accessibilityHidden(true)
    }
}

/// Subtle physical feedback shared by selectable Quiet Stage rows. Selection
/// itself is communicated only by `StageSelectionCheckmark`.
struct StageSelectableRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.14),
                value: configuration.isPressed
            )
    }
}
