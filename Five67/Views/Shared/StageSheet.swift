import SwiftUI

/// Where a video import comes from. Shared so the Add Video sheet, the Feed's
/// allowance check, and the empty-state buttons all name the same two sources.
enum ImportSource: String, Identifiable, Hashable {
    case photos
    case files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: "From Photos"
        case .files:  "From Files"
        }
    }

    var systemImage: String {
        switch self {
        case .photos: "photo.on.rectangle"
        case .files:  "folder"
        }
    }
}

/// The single Quiet Stage bottom-sheet container. Add Video, post-import style
/// tagging, the Library quick-style picker, and video deletion all present
/// through this, so there is one sheet look instead of four near-identical ones.
struct StageSheet<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.sectionTitle)
                        .foregroundStyle(Theme.stagePrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.stageSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                content
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xl2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.stageBackground)
        .presentationBackground(Theme.stageBackground)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

/// A tappable row inside a `StageSheet`. Destructive rows carry the red tint so
/// the intent is visible without relying on a system role's default rendering.
struct StageSheetActionRow: View {
    let title: String
    let systemImage: String
    var isDestructive = false
    let action: () -> Void

    private var foreground: Color {
        isDestructive ? .red : Theme.stagePrimary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 24)
                Text(title)
                    .font(.body.weight(.bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
            .background(
                Theme.stageSurface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(StageSelectableRowButtonStyle())
        .accessibilityLabel(title)
    }
}

/// Add Video. Replaces the old `confirmationDialog` popover. The sheet only
/// reports the chosen source — the Feed still owns the allowance check and the
/// actual picker, so there is one import code path.
struct ImportSourceSheet: View {
    let onSelect: (ImportSource) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StageSheet(
            title: "Add video",
            subtitle: "Bring in a class video to name and loop."
        ) {
            VStack(spacing: Spacing.sm) {
                ForEach([ImportSource.photos, .files]) { source in
                    StageSheetActionRow(title: source.title, systemImage: source.systemImage) {
                        onSelect(source)
                        dismiss()
                    }
                }
            }
        }
    }
}
