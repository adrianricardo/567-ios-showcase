import SwiftData
import SwiftUI

struct OnboardingGateView<Content: View>: View {
    @Environment(AppRouter.self) private var router
    @Environment(UnlockStore.self) private var unlockStore
    @AppStorage(OnboardingPreferences.Keys.status) private var statusRaw = ""
    @Query private var videos: [Video]

    @State private var onboardingSessionStarted = false

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
                OnboardingFlow { result in
                    completeOnboarding(result: result)
                }
                .transition(.identity)
            } else {
                content()
            }
        }
        .onAppear {
            let preferences = OnboardingPreferences()
            // Demo content is never evidence of an existing library.
            let personalCount = videos.count
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
        .onChange(of: statusRaw) { _, newValue in
            guard
                let newStatus = OnboardingStatus(rawValue: newValue),
                OnboardingGatePolicy.shouldPresent(status: newStatus)
            else { return }
            onboardingSessionStarted = true
        }
    }

    private func completeOnboarding(result: FeedSelection?) {
        // Establish the destination and its result before mounting RootView so
        // the Feed never flashes its default state on the way to the seed video.
        router.showFeedAfterOnboarding(result)
        // Completion is only reached from the paywall (purchase or "Not now").
        // Clears the seed ID while deliberately retaining the seed content.
        OnboardingPreferences().markCompleted()
        statusRaw = OnboardingStatus.completed.rawValue
        onboardingSessionStarted = false
    }
}
