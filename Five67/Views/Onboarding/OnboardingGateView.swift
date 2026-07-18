import SwiftData
import SwiftUI

struct OnboardingGateView<Content: View>: View {
    @Environment(AppRouter.self) private var router
    @Environment(UnlockStore.self) private var unlockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OnboardingPreferences.Keys.hasCompleted) private var hasCompletedOnboarding = false
    @Query private var videos: [Video]

    @State private var onboardingSessionStarted = false
    @State private var showLibraryReadyToast = false

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            if onboardingSessionStarted && !hasCompletedOnboarding {
                OnboardingFlow { importedVideoID in
                    completeOnboarding(importedVideoID: importedVideoID)
                }
                .transition(.identity)
            } else {
                content()
                    .overlay(alignment: .top) {
                        if showLibraryReadyToast {
                            LibraryReadyToast()
                                .padding(.top, Spacing.xl2)
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .move(edge: .top).combined(with: .opacity)
                                )
                        }
                    }
            }
        }
        .onAppear {
            unlockStore.start(existingLibraryCount: videos.count)
            if OnboardingGatePolicy.shouldPresent(
                hasCompletedOnboarding: hasCompletedOnboarding,
                videoCount: videos.count
            ) {
                onboardingSessionStarted = true
            }
        }
    }

    private func completeOnboarding(importedVideoID: UUID?) {
        // Establish the destination and its result before mounting RootView so
        // onboarding never flashes the default Feed state on the way to Library.
        router.showLibraryAfterOnboarding(importedVideoID: importedVideoID)
        OnboardingPreferences().markCompleted()
        hasCompletedOnboarding = true
        onboardingSessionStarted = false

        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.28)) {
            showLibraryReadyToast = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    showLibraryReadyToast = false
                }
            }
        }
    }
}

private struct LibraryReadyToast: View {
    var body: some View {
        Label("Your library's ready.", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, Spacing.lg)
            .frame(height: Spacing.touchTarget)
            .liquidGlass(in: Capsule(), interactive: false)
            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
            .accessibilityIdentifier("library-ready-toast")
    }
}
