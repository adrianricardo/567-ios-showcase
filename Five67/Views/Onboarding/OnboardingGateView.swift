import SwiftData
import SwiftUI

struct OnboardingGateView<Content: View>: View {
    @Environment(AppRouter.self) private var router
    @Environment(UnlockStore.self) private var unlockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OnboardingPreferences.Keys.status) private var statusRaw = ""
    @Query private var videos: [Video]

    @State private var onboardingSessionStarted = false
    @State private var showLibraryReadyToast = false

    private var status: OnboardingStatus {
        OnboardingStatus(rawValue: statusRaw) ?? .notStarted
    }

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            if onboardingSessionStarted && status != .completed {
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
            let preferences = OnboardingPreferences()
            // Demo content is never evidence of an existing library.
            let personalCount = videos.personalVideoCount
            let resolved = preferences.resolveStatus(existingLibraryCount: personalCount)

            // A fresh install that is still inside onboarding must never let its
            // own seed content grandfather it into legacy-unlimited access.
            unlockStore.start(
                existingLibraryCount: resolved == .completed ? personalCount : 0
            )

            if OnboardingGatePolicy.shouldPresent(status: resolved) {
                preferences.markInProgress()
                onboardingSessionStarted = true
            }
        }
    }

    private func completeOnboarding(importedVideoID: UUID?) {
        // Establish the destination and its result before mounting RootView so
        // onboarding never flashes the default Feed state on the way to Library.
        router.showLibraryAfterOnboarding(importedVideoID: importedVideoID)
        // Completion is only reached from the paywall (purchase or "Not now").
        // Clears the seed ID while deliberately retaining the seed content.
        OnboardingPreferences().markCompleted()
        statusRaw = OnboardingStatus.completed.rawValue
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
