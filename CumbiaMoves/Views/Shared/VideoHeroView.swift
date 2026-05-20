import SwiftUI

/// Unified player + trim track hero used by both VideoDetail and MovesView.
///
/// Lays out, on a black backdrop:
/// - a rounded-corner player surface,
/// - an overlaid `TimestampPill` at top-center,
/// - a configurable rail of `RailIcon` buttons at top-trailing,
/// - a `TrimTrackView` directly below the player.
///
/// Mute state is bridged to the shared `PlaybackSession` so toggling it on
/// one screen carries across to others within the same app session.
struct VideoHeroView<Rail: View>: View {
    let controller: PlaybackController
    let video: Video
    let moves: [Move]
    let allowsMarkerEditing: Bool
    var showsPlaceholderWhenEmpty: Bool = false
    var onTapSegment: ((Move, TimeInterval) -> Void)? = nil
    var onHandleDragComplete: (() -> Void)? = nil
    @ViewBuilder let rail: () -> Rail

    @Environment(PlaybackSession.self) private var session

    private var playerAspectRatio: CGFloat {
        let size = controller.videoSize
        guard size.width > 0, size.height > 0 else { return 9.0 / 16.0 }
        return size.width / size.height
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                VideoPlayerSurface(controller: controller)
                    .aspectRatio(playerAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .overlay(alignment: .top) {
                TimestampPill(time: controller.currentTime)
                    .padding(.top, 18)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                rail()
                    .padding(.top, 18)
                    .padding(.trailing, 18)
            }

            TrimTrackView(
                controller: controller,
                videoID: video.id,
                videoURL: video.fileURL,
                moves: moves,
                allowsMarkerEditing: allowsMarkerEditing,
                fillsVisibleRange: true,
                showsPlaceholderWhenEmpty: showsPlaceholderWhenEmpty,
                onTapSegment: onTapSegment,
                onHandleDragComplete: onHandleDragComplete
            )
            .frame(height: 52)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(Color.black.ignoresSafeArea(edges: .top))
        .onAppear {
            controller.isMuted = session.isMuted
        }
        .onChange(of: session.isMuted) { _, newValue in
            controller.isMuted = newValue
        }
    }
}

// MARK: - Standard rail buttons

struct MuteRailButton: View {
    @Environment(PlaybackSession.self) private var session

    var body: some View {
        Button {
            session.isMuted.toggle()
            Haptics.light()
        } label: {
            RailIcon(systemName: session.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        }
        .accessibilityLabel(session.isMuted ? "Unmute" : "Mute")
    }
}

struct LoopRailButton: View {
    let controller: PlaybackController

    var body: some View {
        Button {
            controller.isLooping.toggle()
            Haptics.light()
        } label: {
            RailIcon(systemName: "repeat", active: controller.isLooping)
        }
        .accessibilityLabel(controller.isLooping ? "Loop on" : "Loop off")
    }
}

struct SplitRailButton: View {
    let controller: PlaybackController
    let onSplit: () -> Void

    var body: some View {
        Button {
            onSplit()
        } label: {
            RailIcon(systemName: "scissors")
        }
        .disabled(controller.duration == 0)
        .accessibilityLabel("Split")
    }
}
