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
/// This deliberately builds from the app's *real* surfaces — `StageThumbnailView`
/// (including its now-playing cue), the move row's name/duration pairing, and the
/// looping progress bar — instead of a screenshot, so onboarding can never drift
/// out of date with the shipped UI.
struct OnboardingProductPreview: View {
    let reduceMotion: Bool
    var accent: Color = StyleAccentPalette.salsa.color

    /// `true` adds the "Add name" affordance to the second row, showing the
    /// unnamed → named transformation the Payoff beat describes.
    var showsUnnamedRow = false

    @State private var loopProgress: CGFloat = 0.12

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
                LinearGradient(
                    colors: [Theme.stageRaisedSurface, Theme.stageSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "figure.dance")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(accent)

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
        .onAppear {
            guard !reduceMotion else {
                loopProgress = 0.72
                return
            }
            withAnimation(.linear(duration: 5.7).repeatForever(autoreverses: false)) {
                loopProgress = 0.94
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
