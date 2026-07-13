import Foundation
import Testing
@testable import Five67

struct OnboardingTests {
    @Test func onboarding_shows_only_when_uncompleted_and_library_empty() {
        #expect(OnboardingGatePolicy.shouldPresent(hasCompletedOnboarding: false, videoCount: 0))
        #expect(!OnboardingGatePolicy.shouldPresent(hasCompletedOnboarding: true, videoCount: 0))
        #expect(!OnboardingGatePolicy.shouldPresent(hasCompletedOnboarding: false, videoCount: 1))
        #expect(!OnboardingGatePolicy.shouldPresent(hasCompletedOnboarding: true, videoCount: 1))
    }

    @Test func onboarding_preferences_persist_completion_and_answers() throws {
        let suiteName = "OnboardingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = OnboardingPreferences(defaults: defaults)
        #expect(!preferences.hasCompletedOnboarding)
        #expect(preferences.savedValueProps().isEmpty)
        #expect(preferences.savedDanceStyles().isEmpty)
        #expect(preferences.savedVideoVolume() == nil)

        preferences.saveValueProps(["Practice", "Organize"])
        preferences.saveDanceStyles(["Salsa", "Bachata"])
        preferences.saveVideoVolume("A stash (10–50)")
        preferences.markCompleted()

        let reloaded = OnboardingPreferences(defaults: defaults)
        #expect(reloaded.hasCompletedOnboarding)
        #expect(reloaded.savedValueProps() == Set(["Practice", "Organize"]))
        #expect(reloaded.savedDanceStyles() == Set(["Salsa", "Bachata"]))
        #expect(reloaded.savedVideoVolume() == "A stash (10–50)")
    }
}
