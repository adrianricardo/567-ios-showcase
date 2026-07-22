import SwiftUI

/// The canonical style-row list. Every surface that offers a style choice —
/// the post-import tagging sheet, the Library quick picker, and the Styles tab —
/// renders these rows so identity color, selection cue, and accessibility stay
/// identical. The caller supplies what a selection *means*; this view never
/// routes or mutates anything itself.
struct StyleSelectionList: View {
    let styles: [Style]
    let selectedStyleID: UUID?
    /// Shows the "All styles" row, which reports `nil` on selection.
    var includesAllStyles = false
    let onSelect: (Style?) -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if includesAllStyles {
                StageSelectableRow(
                    title: "All styles",
                    isSelected: selectedStyleID == nil,
                    action: { onSelect(nil) }
                )
            }
            ForEach(styles) { style in
                StageSelectableRow(
                    title: style.name,
                    identityColor: StyleAccentPalette.accent(forName: style.name, id: style.id)?.color,
                    isSelected: style.id == selectedStyleID,
                    action: { onSelect(style) }
                )
            }
        }
    }
}

/// The two sheet-shaped uses of `StyleSelectionList`. Style *management*
/// (create, rename, export, durable unlock) stays in the Styles tab.
enum StyleSelectionContext: Equatable {
    /// Library's style chip — changes the global filter.
    case quickFilter
    /// Fired right after an import to tag what just arrived.
    case tagImport(count: Int)

    var title: String {
        switch self {
        case .quickFilter:
            "Style"
        case .tagImport(let count):
            count > 1 ? "Tag \(count) videos" : "What style is this?"
        }
    }

    var subtitle: String {
        switch self {
        case .quickFilter:
            "Filter the feed and library to one style. Manage styles in the Styles tab."
        case .tagImport:
            "Tagging keeps videos in the right style mode. You can change it later from the editor."
        }
    }

    var includesAllStyles: Bool {
        switch self {
        case .quickFilter: true
        case .tagImport:   false
        }
    }

    /// Title for the trailing dismissal action, when the context has one.
    var secondaryActionTitle: String? {
        switch self {
        case .quickFilter: nil
        case .tagImport:   "Skip"
        }
    }
}

struct StyleSelectionSheet: View {
    let context: StyleSelectionContext
    let styles: [Style]
    let selectedStyleID: UUID?
    let onSelect: (Style?) -> Void
    /// Called when the user dismisses via the context's secondary action.
    var onSkip: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StageSheet(title: context.title, subtitle: context.subtitle) {
            VStack(spacing: Spacing.md) {
                StyleSelectionList(
                    styles: styles,
                    selectedStyleID: selectedStyleID,
                    includesAllStyles: context.includesAllStyles
                ) { style in
                    onSelect(style)
                    dismiss()
                }

                if let secondaryActionTitle = context.secondaryActionTitle {
                    Button(secondaryActionTitle) {
                        onSkip?()
                        dismiss()
                    }
                    .buttonStyle(StageSecondaryActionButtonStyle())
                }
            }
        }
    }
}
