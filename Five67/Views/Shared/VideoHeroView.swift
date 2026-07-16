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
    var accentColor: Color = Color.accentColor
    var showsPlaceholderWhenEmpty: Bool = false
    var onTapSegment: ((Move, TimeInterval) -> Void)? = nil
    var onHandleDragComplete: (() -> Void)? = nil
    var focusesPlaybackOnAppear = false
    @ViewBuilder let rail: () -> Rail

    @Environment(PlaybackSession.self) private var session
    @AccessibilityFocusState private var playbackAccessibilityFocus: Bool

    private var playerAspectRatio: CGFloat {
        let size = controller.videoSize
        guard size.width > 0, size.height > 0 else { return 9.0 / 16.0 }
        return size.width / size.height
    }

    var body: some View {
        VStack(spacing: Spacing.none) {
            ZStack {
                Color.black
                VideoPlayerSurface(controller: controller)
                    .aspectRatio(playerAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(Spacing.md)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Video playback")
                    .accessibilityValue(playbackAccessibilityValue)
                    .accessibilityHint(controller.isPlaying ? "Double tap to pause" : "Double tap to play")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityFocused($playbackAccessibilityFocus)
                    .accessibilityAction {
                        controller.toggle()
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .overlay(alignment: .top) {
                TimestampPill(time: controller.currentTime)
                    .padding(.top, Spacing.lgPlus)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                rail()
                    .padding(.top, Spacing.lgPlus)
                    .padding(.trailing, Spacing.lgPlus)
            }
            .overlay {
                if let message = controller.playbackErrorMessage {
                    PlaybackFailureView(message: message, retry: controller.retry)
                        .padding(Spacing.xl2)
                }
            }

            TrimTrackView(
                controller: controller,
                videoID: video.id,
                videoURL: video.fileURL,
                moves: moves,
                allowsMarkerEditing: allowsMarkerEditing,
                accentColor: accentColor,
                fillsVisibleRange: true,
                showsPlaceholderWhenEmpty: showsPlaceholderWhenEmpty,
                onTapSegment: onTapSegment,
                onHandleDragComplete: onHandleDragComplete
            )
            .frame(height: Spacing.primaryButtonHeight)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.mdPlus)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.black.ignoresSafeArea(edges: .top))
        .onAppear {
            controller.isMuted = session.isMuted
            if focusesPlaybackOnAppear {
                Task { @MainActor in
                    await Task.yield()
                    playbackAccessibilityFocus = true
                }
            }
        }
        .onChange(of: session.isMuted) { _, newValue in
            controller.isMuted = newValue
        }
    }

    private var playbackAccessibilityValue: String {
        let state = controller.isPlaying ? "Playing" : "Paused"
        let duration = controller.duration > 0 ? controller.duration : video.duration
        return "\(state), \(formatTime(controller.currentTime)) of \(formatTime(duration))"
    }
}

struct PlaybackFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, Spacing.lg)
                .frame(minHeight: Spacing.touchTarget)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(Spacing.lg)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
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
        .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
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
        .accessibilityLabel("Loop")
        .accessibilityValue(controller.isLooping ? "On" : "Off")
        .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
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
        .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
    }
}
