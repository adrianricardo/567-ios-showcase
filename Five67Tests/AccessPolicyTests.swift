import Foundation
import Testing
@testable import Five67

struct AccessPolicyTests {
    @Test func freePersonalVideoImportsStopExactlyAtThree() {
        let scenarios = [
            (current: 0, requested: 3, allowed: 3, prompts: false),
            (current: 2, requested: 1, allowed: 1, prompts: false),
            (current: 2, requested: 3, allowed: 1, prompts: true),
            (current: 3, requested: 1, allowed: 0, prompts: true),
            (current: 5, requested: 1, allowed: 0, prompts: true)
        ]
        for scenario in scenarios {
            let result = AccessPolicy.videoImportAllowance(
                accessLevel: .free,
                personalVideoCount: scenario.current,
                requestedCount: scenario.requested
            )

            #expect(result.allowedCount == scenario.allowed)
            #expect(result.requiresUnlock == scenario.prompts)
        }
    }

    @Test func paidAndLegacyUsersCanImportBeyondTheFreeCap() {
        for level in [AccessLevel.paid, .legacy] {
            let result = AccessPolicy.videoImportAllowance(
                accessLevel: level,
                personalVideoCount: 3,
                requestedCount: 4
            )

            #expect(result == VideoImportAllowance(allowedCount: 4, requiresUnlock: false))
        }
    }

    @Test func freeStylePolicyAllowsAllAndOneClaimedStyleOnly() {
        let salsa = UUID()
        let bachata = UUID()

        #expect(AccessPolicy.canUseStyle(
            accessLevel: .free,
            claimedFreeStyleID: nil,
            requestedStyleID: salsa
        ))
        #expect(AccessPolicy.canUseStyle(
            accessLevel: .free,
            claimedFreeStyleID: salsa,
            requestedStyleID: nil
        ))
        #expect(AccessPolicy.canUseStyle(
            accessLevel: .free,
            claimedFreeStyleID: salsa,
            requestedStyleID: salsa
        ))
        #expect(!AccessPolicy.canUseStyle(
            accessLevel: .free,
            claimedFreeStyleID: salsa,
            requestedStyleID: bachata
        ))
        #expect(AccessPolicy.canUseStyle(
            accessLevel: .paid,
            claimedFreeStyleID: salsa,
            requestedStyleID: bachata
        ))
        #expect(AccessPolicy.canUseStyle(
            accessLevel: .legacy,
            claimedFreeStyleID: salsa,
            requestedStyleID: bachata
        ))
    }

    @Test func receiptGrandfatheringIsProductionOnly() {
        let scenarios = [
            (AppInstallEnvironment.production, "52", true),
            (AppInstallEnvironment.production, "53", false),
            (AppInstallEnvironment.sandbox, "1.0", false),
            (AppInstallEnvironment.xcode, "1.0", false),
            (AppInstallEnvironment.unknown, "1", false)
        ]
        for (environment, originalBuild, expected) in scenarios {
            let result = AccessPolicy.shouldGrantLegacyUnlimited(
                existingLibraryCount: 0,
                installEvidence: AppInstallEvidence(
                    environment: environment,
                    originalBuildVersion: originalBuild
                )
            )

            #expect(result == expected)
        }
    }

    @Test func existingLibraryIsAlwaysLegacyUnlimited() {
        #expect(AccessPolicy.shouldGrantLegacyUnlimited(
            existingLibraryCount: 1,
            installEvidence: nil
        ))
        #expect(AccessPolicy.shouldGrantLegacyUnlimited(
            existingLibraryCount: 12,
            installEvidence: AppInstallEvidence(
                environment: .sandbox,
                originalBuildVersion: "1.0"
            )
        ))
    }

    @Test func personalVideoCountExcludesDemoRows() {
        let personalA = Video(displayName: "A", localFilename: "a.mov", duration: 1)
        let demo = Video(displayName: "Demo", localFilename: "demo.mov", duration: 1, isDemo: true)
        let personalB = Video(displayName: "B", localFilename: "b.mov", duration: 1)
        let all = [personalA, demo, personalB]

        #expect(all.personalVideoCount == 2)
        #expect(all.personalVideos.count == 2)
        #expect(!all.personalVideos.contains { $0.isDemo })
    }

    @Test @MainActor func clearingLastPersonalVideoResetsFreeStyleClaim() throws {
        let suiteName = "AccessPolicyClaimReset-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let salsa = UUID()

        let store = UnlockStore(defaults: defaults)
        store.recordStyleUse(salsa)
        #expect(store.claimedFreeStyleID == salsa)

        // A demo-only library (personal count 0 because demo is excluded by the
        // caller) or a fully cleared library resets the claim.
        store.recountPersonalVideos(1)
        #expect(store.claimedFreeStyleID == salsa)

        store.recountPersonalVideos(0)
        #expect(store.claimedFreeStyleID == nil)
        #expect(store.canUseStyle(UUID()))
        #expect(UnlockStore(defaults: defaults).claimedFreeStyleID == nil)
    }

    @Test @MainActor func firstPersonalStyleSucceedsAndSecondRequiresUnlock() throws {
        let suiteName = "AccessPolicySecondStyle-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let salsa = UUID()
        let bachata = UUID()

        let store = UnlockStore(defaults: defaults)
        #expect(store.canUseStyle(salsa))
        store.recordStyleUse(salsa)

        #expect(store.canUseStyle(salsa))
        #expect(!store.canUseStyle(bachata))
    }

    @Test @MainActor func claimedFreeStylePersistsAcrossStoreRelaunch() throws {
        let suiteName = "AccessPolicyTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let salsa = UUID()
        let bachata = UUID()

        let firstStore = UnlockStore(defaults: defaults)
        firstStore.recordStyleUse(salsa)

        let reloadedStore = UnlockStore(defaults: defaults)
        #expect(reloadedStore.claimedFreeStyleID == salsa)
        #expect(reloadedStore.canUseStyle(salsa))
        #expect(!reloadedStore.canUseStyle(bachata))
    }

    @Test @MainActor func legacyDecisionPersistsAndSandboxReceiptDoesNotFalseGrandfather() throws {
        let legacySuiteName = "AccessPolicyLegacyTests-\(UUID().uuidString)"
        let legacyDefaults = try #require(UserDefaults(suiteName: legacySuiteName))
        defer { legacyDefaults.removePersistentDomain(forName: legacySuiteName) }

        let legacyStore = UnlockStore(defaults: legacyDefaults)
        legacyStore.evaluateLegacyAccess(existingLibraryCount: 1, installEvidence: nil)
        #expect(legacyStore.accessLevel == .legacy)
        #expect(UnlockStore(defaults: legacyDefaults).accessLevel == .legacy)

        let sandboxSuiteName = "AccessPolicySandboxTests-\(UUID().uuidString)"
        let sandboxDefaults = try #require(UserDefaults(suiteName: sandboxSuiteName))
        defer { sandboxDefaults.removePersistentDomain(forName: sandboxSuiteName) }

        let sandboxStore = UnlockStore(defaults: sandboxDefaults)
        sandboxStore.evaluateLegacyAccess(
            existingLibraryCount: 0,
            installEvidence: AppInstallEvidence(
                environment: .sandbox,
                originalBuildVersion: "1.0"
            )
        )
        #expect(sandboxStore.accessLevel == .free)
    }

    @Test @MainActor func resolvedFreeInstallDoesNotBecomeLegacyAfterImportingContent() throws {
        let suiteName = "AccessPolicyResolvedFreeTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunchStore = UnlockStore(defaults: defaults)
        firstLaunchStore.evaluateLegacyAccess(
            existingLibraryCount: 0,
            installEvidence: AppInstallEvidence(
                environment: .sandbox,
                originalBuildVersion: "1.0"
            )
        )
        #expect(firstLaunchStore.accessLevel == .free)

        let relaunchedStore = UnlockStore(defaults: defaults)
        relaunchedStore.evaluateLegacyAccess(
            existingLibraryCount: 1,
            installEvidence: nil
        )

        #expect(relaunchedStore.accessLevel == .free)
    }

    @Test @MainActor func unresolvedEmptyInstallDoesNotBecomeLegacyAfterImportingContent() throws {
        let suiteName = "AccessPolicyUnresolvedFreeTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunchStore = UnlockStore(defaults: defaults)
        firstLaunchStore.evaluateLegacyAccess(
            existingLibraryCount: 0,
            installEvidence: nil
        )

        let relaunchedStore = UnlockStore(defaults: defaults)
        relaunchedStore.evaluateLegacyAccess(
            existingLibraryCount: 1,
            installEvidence: nil
        )

        #expect(relaunchedStore.accessLevel == .free)
    }

    @Test func purchaseOutcomesPreserveOrChangePaidAccessTruthfully() {
        let scenarios = [
            (
                UnlockPurchaseOutcome.verified(active: true),
                UnlockPurchaseResolution(paidAccessOverride: true, message: nil)
            ),
            (
                UnlockPurchaseOutcome.verified(active: false),
                UnlockPurchaseResolution(paidAccessOverride: false, message: nil)
            ),
            (
                UnlockPurchaseOutcome.pending,
                UnlockPurchaseResolution(
                    paidAccessOverride: nil,
                    message: "Purchase pending approval."
                )
            ),
            (
                UnlockPurchaseOutcome.cancelled,
                UnlockPurchaseResolution(paidAccessOverride: nil, message: nil)
            ),
            (
                UnlockPurchaseOutcome.unverified,
                UnlockPurchaseResolution(
                    paidAccessOverride: nil,
                    message: "We couldn't verify that purchase."
                )
            ),
            (
                UnlockPurchaseOutcome.failed,
                UnlockPurchaseResolution(
                    paidAccessOverride: nil,
                    message: "Purchase failed. Try again when you're online."
                )
            )
        ]
        for (outcome, expected) in scenarios {
            #expect(AccessPolicy.purchaseResolution(for: outcome) == expected)
        }
    }
}
