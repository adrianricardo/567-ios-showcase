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

    @Test func known_dance_styles_have_locked_brand_accents() {
        #expect(StyleAccentPalette.accent(forName: "Salsa")?.rgb == 0xFF6B4A)
        #expect(StyleAccentPalette.accent(forName: "Cumbia")?.rgb == 0xFFD166)
        #expect(StyleAccentPalette.accent(forName: "Bachata")?.rgb == 0xFF9EB5)
        #expect(StyleAccentPalette.accent(forName: "Kizomba")?.rgb == 0xB7A0FF)
        #expect(StyleAccentPalette.accent(forName: "Zouk")?.rgb == 0x71D7E8)
        #expect(StyleAccentPalette.accent(forName: "Merengue")?.rgb == 0xB8F05A)
        #expect(StyleAccentPalette.accent(forName: "All") == nil)
        #expect(StyleAccentPalette.accent(forName: "Other") == nil)
    }

    @Test func custom_style_accent_is_deterministic_and_approved() throws {
        let id = try #require(UUID(uuidString: "A5CBAAB4-7C8C-4EB6-8991-530E2B35F695"))
        let first = try #require(StyleAccentPalette.accent(forName: "West Coast Swing", id: id))
        let second = try #require(StyleAccentPalette.accent(forName: "West Coast Swing", id: id))

        #expect(first == second)
        #expect(StyleAccentPalette.approved.contains(first))
    }

    @Test func quiet_stage_text_pairs_exceed_accessibility_contrast_targets() {
        #expect(StagePalette.contrastRatio(StagePalette.ink, StagePalette.actionSurface) >= 7)
        #expect(StagePalette.contrastRatio(StagePalette.secondary, StagePalette.background) >= 4.5)

        for accent in StyleAccentPalette.approved {
            #expect(StagePalette.contrastRatio(StagePalette.ink, accent.rgb) >= 4.5)
        }
    }
}

struct LibraryPresentationTests {
    @Test @MainActor func onboarding_arrival_targets_library_and_preserves_the_imported_result() {
        let router = AppRouter()
        let videoID = UUID()

        router.showLibraryAfterOnboarding(importedVideoID: videoID)

        #expect(router.selectedTab == .library)
        #expect(router.pendingLibraryArrival == LibraryArrival(videoID: videoID))
        #expect(router.pendingFeedSelection == nil)
    }

    @Test @MainActor func library_selection_routes_one_result_to_feed_with_a_focus_request() {
        let router = AppRouter()
        router.selectedTab = .library
        let selection = FeedSelection(videoID: UUID(), moveID: UUID())

        router.showInFeed(selection)

        #expect(router.selectedTab == .feed)
        #expect(router.pendingFeedSelection == selection)
        #expect(router.feedFocusRequestID != nil)
    }

    @Test func local_mode_control_has_two_stable_scan_labels() {
        #expect(PaneTab.allCases == [.moves, .videos])
        #expect(PaneTab.moves.label == "Moves")
        #expect(PaneTab.videos.label == "Videos")
    }
}
