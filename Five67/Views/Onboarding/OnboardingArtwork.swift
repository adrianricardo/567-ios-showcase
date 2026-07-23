import AVFoundation
import SwiftUI

struct Five67BrandMark: View {
    var visibleDigits = 3

    var body: some View {
        ZStack {
            ForEach(Array(["LogoDigit5", "LogoDigit6", "LogoDigit7"].enumerated()), id: \.offset) { index, name in
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(index < visibleDigits ? 1 : 0)
                    .scaleEffect(index < visibleDigits ? 1 : 0.72)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("567")
    }
}

/// Live product composition shown on the Hook and Payoff beats.
///
/// The bundled clip plays inside the app's real move surfaces so the core
/// product promise is demonstrated instead of represented by a placeholder.
struct OnboardingProductPreview: View {
    let reduceMotion: Bool
    var accent: Color = StyleAccentPalette.salsa.color

    /// `true` adds the "Add name" affordance to the second row, showing the
    /// unnamed → named transformation the Payoff beat describes.
    var showsUnnamedRow = false

    @State private var loopProgress: CGFloat = 0.12

    private var demoURL: URL? {
        Bundle.main.url(forResource: "OnboardingDemo", withExtension: "mp4")
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            previewStage

            OnboardingPreviewMoveRow(
                name: "Right turn",
                duration: "0:12",
                isPlaying: true,
                accent: accent
            )

            OnboardingPreviewMoveRow(
                name: showsUnnamedRow ? "" : "Inside turn",
                duration: "0:09",
                isPlaying: false,
                accent: accent
            )
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.stageSurface,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "A class video split into named moves. Right turn is looping."
        )
    }

    private var previewStage: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Color.black

                if let demoURL {
                    OnboardingLoopingVideo(
                        url: demoURL,
                        shouldPlay: !reduceMotion,
                        progress: $loopProgress
                    )
                    .accessibilityIdentifier("onboardingDemoVideo")
                }

                VStack {
                    Spacer()
                    HStack {
                        Text("Right turn")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.stagePrimary)
                        Spacer()
                        Text("LOOPING")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(accent)
                    }
                    .padding(Spacing.smPlus)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.stageRaisedSurface)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(18, proxy.size.width * loopProgress))
                }
            }
            .frame(height: 6)
        }
        .accessibilityHidden(true)
        .onChange(of: reduceMotion, initial: true) { _, isReduced in
            if isReduced {
                loopProgress = 0
            }
        }
    }
}

/// A silent, control-free player dedicated to the bundled onboarding proof clip.
/// `AVPlayerLooper` owns the repeat boundary so the loop remains seamless.
private struct OnboardingLoopingVideo: UIViewRepresentable {
    let url: URL
    let shouldPlay: Bool
    @Binding var progress: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress)
    }

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.videoGravity = .resizeAspectFill
        view.player = context.coordinator.player
        context.coordinator.load(url)
        updatePlayback(context.coordinator)
        return view
    }

    func updateUIView(_ view: PlayerSurfaceView, context: Context) {
        context.coordinator.progress = $progress
        updatePlayback(context.coordinator)
    }

    static func dismantleUIView(_ view: PlayerSurfaceView, coordinator: Coordinator) {
        coordinator.stop()
        view.player = nil
    }

    private func updatePlayback(_ coordinator: Coordinator) {
        if shouldPlay {
            coordinator.player.play()
        } else {
            coordinator.player.pause()
            coordinator.player.seek(to: .zero)
        }
    }

    @MainActor
    final class Coordinator {
        let player = AVQueuePlayer()
        var progress: Binding<CGFloat>

        private var looper: AVPlayerLooper?
        private var timeObserver: Any?
        private var loadedURL: URL?

        init(progress: Binding<CGFloat>) {
            self.progress = progress
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(value: 1, timescale: 30),
                queue: .main
            ) { [weak self] time in
                MainActor.assumeIsolated {
                    guard let self,
                          let duration = self.player.currentItem?.duration.seconds,
                          duration.isFinite,
                          duration > 0 else { return }
                    self.progress.wrappedValue = min(max(time.seconds / duration, 0), 1)
                }
            }
        }

        func load(_ url: URL) {
            guard loadedURL != url else { return }
            loadedURL = url
            looper = nil
            player.removeAllItems()
            looper = AVPlayerLooper(
                player: player,
                templateItem: AVPlayerItem(url: url)
            )
        }

        func stop() {
            player.pause()
            looper = nil
            player.removeAllItems()
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
        }

        deinit {
            MainActor.assumeIsolated {
                if let timeObserver {
                    player.removeTimeObserver(timeObserver)
                }
            }
        }
    }
}

/// The move row as the editor draws it, minus the model dependency. Kept next to
/// `OnboardingProductPreview` so both onboarding compositions stay in step with
/// `MoveRowView`'s layout.
private struct OnboardingPreviewMoveRow: View {
    let name: String
    let duration: String
    let isPlaying: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            StageThumbnailView(
                videoID: nil,
                fileURL: nil,
                size: CGSize(width: 54, height: 40),
                isPlaying: isPlaying,
                accent: accent
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(name.isEmpty ? "Unnamed" : name)
                    .font(.body)
                    .foregroundStyle(name.isEmpty ? Theme.stageSecondary : Theme.stagePrimary)
                    .lineLimit(1)
                Text(duration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.stageSecondary)
            }

            Spacer(minLength: Spacing.sm)

            if name.isEmpty {
                Text("Add name")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 34)
                    .background(Theme.stageRaisedSurface, in: Capsule())
            }
        }
        .padding(Spacing.smPlus)
        .background(
            Theme.stageRaisedSurface,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}
