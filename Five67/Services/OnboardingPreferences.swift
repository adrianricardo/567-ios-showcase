import Foundation

/// Explicit onboarding lifecycle. Replaces the old Boolean-only
/// `hasCompletedOnboarding` gate so an interrupted fresh install can be resumed
/// without duplicating its seed import.
enum OnboardingStatus: String {
    case notStarted
    case inProgress
    case completed
}

enum OnboardingGatePolicy {
    /// Onboarding is presented for fresh installs that have not finished it.
    ///
    /// `inProgress` always presents — even once its seed video exists — because
    /// the narrative restarts at Hook and reuses that video when it reaches Seed.
    /// Library content alone never re-gates a `completed` (or grandfathered) user.
    static func shouldPresent(status: OnboardingStatus) -> Bool {
        switch status {
        case .notStarted, .inProgress: true
        case .completed:               false
        }
    }

    /// One-time migration from the pre-V5 Boolean gate.
    ///
    /// - existing `hasCompleted == true` → `completed`
    /// - no status + nonempty pre-update library → `completed` (grandfathered:
    ///   these users must never be shown onboarding, and keep legacy-unlimited)
    /// - no status + empty library → `notStarted`
    static func migratedStatus(
        persistedStatus: String?,
        hasCompletedLegacyFlag: Bool,
        existingLibraryCount: Int
    ) -> OnboardingStatus {
        if let persistedStatus, let status = OnboardingStatus(rawValue: persistedStatus) {
            return status
        }
        if hasCompletedLegacyFlag { return .completed }
        return existingLibraryCount > 0 ? .completed : .notStarted
    }
}

struct OnboardingPreferences {
    enum Keys {
        static let status = "com.nopalstudio.five67.onboarding.status"
        static let seedVideoID = "com.nopalstudio.five67.onboarding.seedVideoID"

        /// Pre-V5 Boolean gate. Read once for migration, then left in place so a
        /// downgrade doesn't re-run onboarding. Never written by new code.
        static let hasCompleted = "com.nopalstudio.five67.onboarding.hasCompleted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var status: OnboardingStatus {
        defaults.string(forKey: Keys.status)
            .flatMap(OnboardingStatus.init(rawValue:)) ?? .notStarted
    }

    /// Resolves and persists the status once, folding in the legacy Boolean and
    /// the pre-update library size. Safe to call on every launch — after the
    /// first resolution the stored status wins.
    @discardableResult
    func resolveStatus(existingLibraryCount: Int) -> OnboardingStatus {
        let resolved = OnboardingGatePolicy.migratedStatus(
            persistedStatus: defaults.string(forKey: Keys.status),
            hasCompletedLegacyFlag: defaults.bool(forKey: Keys.hasCompleted),
            existingLibraryCount: existingLibraryCount
        )
        setStatus(resolved)
        return resolved
    }

    func setStatus(_ status: OnboardingStatus) {
        defaults.set(status.rawValue, forKey: Keys.status)
    }

    func markInProgress() {
        setStatus(.inProgress)
    }

    /// Completion is only reached after the paywall is purchased or dismissed.
    /// The seed ID is dropped here; the seed *content* is deliberately retained.
    func markCompleted() {
        setStatus(.completed)
        clearSeedVideoID()
    }

    // MARK: - Seed video

    var seedVideoID: UUID? {
        defaults.string(forKey: Keys.seedVideoID).flatMap(UUID.init(uuidString:))
    }

    func saveSeedVideoID(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Keys.seedVideoID)
    }

    /// Called when a persisted seed ID no longer resolves to a row/file, so the
    /// Seed step falls back to PhotosPicker/demo actions instead of dead state.
    func clearSeedVideoID() {
        defaults.removeObject(forKey: Keys.seedVideoID)
    }
}
