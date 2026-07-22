import SwiftUI

/// Contextual video-delete confirmation. Replaces the old `confirmationDialog`
/// so the user sees *which* video they are about to remove — thumbnail, name,
/// and the exact named-move impact — instead of a title-only popover.
struct VideoDeleteSheet: View {
    let video: Video
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StageSheet(title: "Delete this video?") {
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    StageThumbnailView(
                        videoID: video.id,
                        fileURL: video.fileURL,
                        size: CGSize(width: 64, height: 44)
                    )
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(video.displayName)
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.stagePrimary)
                            .lineLimit(2)
                        Text(VideoDeletionService.namedMoveImpact(for: video))
                            .font(.footnote)
                            .foregroundStyle(Theme.stageSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(
                    Theme.stageSurface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .accessibilityElement(children: .combine)

                VStack(spacing: Spacing.sm) {
                    StageSheetActionRow(
                        title: "Delete video & moves",
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        onDelete()
                        dismiss()
                    }
                    Button("Cancel") { dismiss() }
                        .buttonStyle(StageSecondaryActionButtonStyle())
                }
            }
        }
    }
}
