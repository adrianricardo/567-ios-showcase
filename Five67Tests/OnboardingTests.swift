import Foundation
import Testing
@testable import Five67

struct OnboardingTests {
    @Test func onboarding_presents_until_it_is_completed() {
        // `inProgress` still presents — the narrative restarts at Hook and
        // reuses its seed video when it reaches Seed.
        #expect(OnboardingGatePolicy.shouldPresent(status: .notStarted))
        #expect(OnboardingGatePolicy.shouldPresent(status: .inProgress))
        #expect(!OnboardingGatePolicy.shouldPresent(status: .completed))
    }

    @Test func existing_installs_are_grandfathered_past_onboarding() {
        // Explicit stored status always wins.
        #expect(OnboardingGatePolicy.migratedStatus(
            persistedStatus: OnboardingStatus.inProgress.rawValue,
            hasCompletedLegacyFlag: false,
            existingLibraryCount: 0
        ) == .inProgress)

        // Pre-V5 Boolean gate.
        #expect(OnboardingGatePolicy.migratedStatus(
            persistedStatus: nil,
            hasCompletedLegacyFlag: true,
            existingLibraryCount: 0
        ) == .completed)

        // No status + existing library → grandfathered, never re-onboarded.
        #expect(OnboardingGatePolicy.migratedStatus(
            persistedStatus: nil,
            hasCompletedLegacyFlag: false,
            existingLibraryCount: 4
        ) == .completed)

        // No status + empty library → genuine fresh install.
        #expect(OnboardingGatePolicy.migratedStatus(
            persistedStatus: nil,
            hasCompletedLegacyFlag: false,
            existingLibraryCount: 0
        ) == .notStarted)
    }

    @Test func interrupted_onboarding_restarts_the_narrative_and_reuses_its_seed() throws {
        let suiteName = "OnboardingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let seedID = UUID()

        let firstRun = OnboardingPreferences(defaults: defaults)
        #expect(firstRun.status == .notStarted)
        #expect(firstRun.seedVideoID == nil)

        firstRun.markInProgress()
        firstRun.saveSeedVideoID(seedID)

        // Process relaunch: still in progress, and the seed survives so the
        // Seed step reuses it instead of importing a duplicate.
        let relaunched = OnboardingPreferences(defaults: defaults)
        #expect(relaunched.status == .inProgress)
        #expect(relaunched.seedVideoID == seedID)
        #expect(OnboardingGatePolicy.shouldPresent(status: relaunched.status))

        // An in-progress install is never mistaken for an existing library.
        #expect(relaunched.resolveStatus(existingLibraryCount: 1) == .inProgress)

        // Completion drops the seed ID but keeps the content.
        relaunched.markCompleted()
        let afterCompletion = OnboardingPreferences(defaults: defaults)
        #expect(afterCompletion.status == .completed)
        #expect(afterCompletion.seedVideoID == nil)
        #expect(!OnboardingGatePolicy.shouldPresent(status: afterCompletion.status))
    }

    @Test func stale_seed_video_id_can_be_cleared_without_losing_progress() throws {
        let suiteName = "OnboardingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = OnboardingPreferences(defaults: defaults)
        preferences.markInProgress()
        preferences.saveSeedVideoID(UUID())

        // Row or file went missing → drop the stale ID, stay in progress so the
        // Seed step falls back to PhotosPicker/demo actions.
        preferences.clearSeedVideoID()

        #expect(preferences.seedVideoID == nil)
        #expect(preferences.status == .inProgress)
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

    @Test @MainActor func add_video_request_routes_to_feed_with_a_fresh_event() {
        let router = AppRouter()
        router.selectedTab = .style

        router.requestAddVideo()
        let firstRequestID = router.addVideoRequestID

        #expect(router.selectedTab == .feed)
        #expect(firstRequestID != nil)

        router.requestAddVideo()

        #expect(router.addVideoRequestID != firstRequestID)
    }

    @Test func local_mode_control_has_two_stable_scan_labels() {
        #expect(PaneTab.allCases == [.moves, .videos])
        #expect(PaneTab.moves.label == "Moves")
        #expect(PaneTab.videos.label == "Videos")
    }
}
