import Foundation
import SwiftUI
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
        // Seed step falls back to PhotosPicker.
        preferences.clearSeedVideoID()

        #expect(preferences.seedVideoID == nil)
        #expect(preferences.status == .inProgress)
    }

    @Test func each_motivation_maps_to_its_approved_payoff_copy() {
        #expect(OnboardingMotivation.remember.label == "Remember moves when I'm out dancing")
        #expect(OnboardingMotivation.practice.label == "Practice what I learned between classes")
        #expect(OnboardingMotivation.organize.label == "Organize my class videos")

        #expect(OnboardingMotivation.remember.payoffHeadline
                == "See every move you've learned in one place.")
        #expect(OnboardingMotivation.practice.payoffHeadline
                == "Loop the exact part until it sticks.")
        #expect(OnboardingMotivation.organize.payoffHeadline
                == "Give every class video a home.")
        #expect(OnboardingMotivation.organize.payoffSupportingCopy
                == "Keep them organized by style instead of buried in Photos.")

        // Every answer must lead somewhere distinct — a duplicated payoff would
        // make the question decorative.
        let headlines = Set(OnboardingMotivation.allCases.map(\.payoffHeadline))
        #expect(headlines.count == OnboardingMotivation.allCases.count)
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

    /// The Quiet Stage neutrals must stay neutral: every channel equal, so no
    /// warm cast competes with the style accents, which are the only color the
    /// app is allowed to spend.
    @Test func quiet_stage_neutrals_carry_no_color_cast() {
        let neutrals: [(String, UInt32)] = [
            ("background", StagePalette.background),
            ("surface", StagePalette.surface),
            ("raisedSurface", StagePalette.raisedSurface),
            ("primary", StagePalette.primary),
            ("secondary", StagePalette.secondary),
            ("actionSurface", StagePalette.actionSurface),
            ("ink", StagePalette.ink)
        ]

        for (name, rgb) in neutrals {
            let red = (rgb >> 16) & 0xFF
            let green = (rgb >> 8) & 0xFF
            let blue = rgb & 0xFF
            #expect(red == green && green == blue, "\(name) is not a pure neutral")
        }
    }

    /// Routine hairlines were removed in P5, which makes the Increase Contrast
    /// branch load-bearing: it is now the *only* thing that draws a boundary.
    /// The simulator's `simctl ui increase_contrast` toggle does not propagate
    /// to app rendering (verified 2026-07-21), so this locks the token logic and
    /// the on-device check stays on the punch list.
    @Test func stage_boundary_is_drawn_only_under_increased_contrast() {
        #expect(Theme.stageBoundary(.standard) == Color.clear)
        #expect(Theme.stageBoundary(.increased) != Color.clear)
    }
}

struct LibraryPresentationTests {
    @Test @MainActor func onboarding_completion_lands_the_feed_on_its_result() {
        let router = AppRouter()
        router.selectedTab = .library
        let result = FeedSelection(videoID: UUID(), moveID: UUID())

        router.showFeedAfterOnboarding(result)

        #expect(router.selectedTab == .feed)
        #expect(router.pendingFeedSelection == result)
        #expect(router.feedFocusRequestID != nil)
    }

    @Test @MainActor func onboarding_completion_without_a_result_still_lands_on_the_feed() {
        let router = AppRouter()
        router.selectedTab = .library

        router.showFeedAfterOnboarding(nil)

        #expect(router.selectedTab == .feed)
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
