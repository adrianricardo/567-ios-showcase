import SwiftUI

/// Where the user is in the onboarding narrative. Passed into the guided editor
/// so the progress cue keeps its single top position across every beat instead
/// of moving when the editor takes over the screen.
struct OnboardingProgress: Equatable {
    let index: Int
    let total: Int
}

struct OnboardingProgressDots: View {
    let progress: OnboardingProgress
    var accent: Color = Theme.stagePrimary

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<progress.total, id: \.self) { index in
                Capsule()
                    .fill(index <= progress.index ? accent : Theme.stageSecondary.opacity(0.25))
                    .frame(width: index == progress.index ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(progress.index + 1) of \(progress.total)")
    }
}
