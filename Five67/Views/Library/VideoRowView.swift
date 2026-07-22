import SwiftUI
import AVFoundation

struct VideoRowView: View {
    let video: Video
    /// Drawn as an overlay on the thumbnail rather than a trailing icon, so the
    /// row's action area stays free.
    var isPlaying = false
    var accent: Color = Theme.stagePrimary

    var body: some View {
        HStack(spacing: Spacing.md) {
            StageThumbnailView(
                videoID: video.id,
                fileURL: video.fileURL,
                size: CGSize(width: 64, height: 44),
                isPlaying: isPlaying,
                accent: accent
            )
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(video.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(Theme.stageSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: Spacing.rowMinHeight)
    }

    private var subtitleText: String {
        let count = video.moves.count
        let moveStr = count == 1 ? "1 move" : "\(count) moves"
        let age = video.importedAt.relativeDescription
        return "\(moveStr) · \(age)"
    }
}

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
