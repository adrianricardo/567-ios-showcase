import SwiftUI
import UIKit

/// The shared video/move thumbnail, and the one place the now-playing cue is
/// drawn. Keeping the cue on the image instead of in the row's trailing action
/// area is what lets "Add name" stay put when a row starts playing.
struct StageThumbnailView: View {
    let videoID: UUID?
    let fileURL: URL?
    /// Frame the thumbnail is captured at. `0` is the video's poster frame.
    var time: TimeInterval = 0
    let size: CGSize
    var isPlaying = false
    var accent: Color = Theme.stagePrimary

    @State private var image: UIImage?

    /// Re-renders when the video, its file, or the requested frame changes.
    private var reloadID: String {
        guard let videoID, let fileURL else { return "missing" }
        return "\(videoID.uuidString)-\(time)-\(fileURL.lastPathComponent)"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.stageRaisedSurface)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(Theme.stageSecondary)
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay { nowPlayingCue }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
        .task(id: reloadID) { await load() }
    }

    @ViewBuilder
    private var nowPlayingCue: some View {
        if isPlaying {
            ZStack {
                Color.black.opacity(0.45)
                Image(systemName: "waveform")
                    .font(.footnote.weight(.black))
                    .foregroundStyle(accent)
                    .shadow(color: .black.opacity(0.6), radius: 3)
            }
            .transition(.opacity)
        }
    }

    private func load() async {
        guard let videoID, let fileURL else {
            image = nil
            return
        }
        image = await ThumbnailService.shared.thumbnail(
            for: fileURL,
            at: time,
            videoID: videoID,
            height: size.height
        )
    }
}
