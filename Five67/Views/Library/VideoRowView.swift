import SwiftUI
import AVFoundation

struct VideoRowView: View {
    let video: Video
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: Spacing.md) {
            thumbnailView
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
        .task { await loadThumbnail() }
    }

    private var thumbnailView: some View {
        Group {
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.stageRaisedSurface)
                    .overlay(Image(systemName: "film").foregroundStyle(Theme.stageSecondary))
            }
        }
        .frame(width: 64, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }

    private var subtitleText: String {
        let count = video.moves.count
        let moveStr = count == 1 ? "1 move" : "\(count) moves"
        let age = video.importedAt.relativeDescription
        return "\(moveStr) · \(age)"
    }

    private func loadThumbnail() async {
        thumbnail = await ThumbnailService.shared.thumbnail(
            for: video.fileURL,
            at: 0,
            videoID: video.id,
            height: 44
        )
    }
}

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
