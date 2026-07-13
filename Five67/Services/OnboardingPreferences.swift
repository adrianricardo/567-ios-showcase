import Foundation

enum OnboardingGatePolicy {
    static func shouldPresent(hasCompletedOnboarding: Bool, videoCount: Int) -> Bool {
        !hasCompletedOnboarding && videoCount == 0
    }
}

struct OnboardingPreferences {
    enum Keys {
        static let hasCompleted = "com.nopalstudio.five67.onboarding.hasCompleted"
        static let valueProps = "com.nopalstudio.five67.onboarding.valueProps"
        static let danceStyles = "com.nopalstudio.five67.onboarding.danceStyles"
        static let videoVolume = "com.nopalstudio.five67.onboarding.videoVolume"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Keys.hasCompleted)
    }

    func markCompleted() {
        defaults.set(true, forKey: Keys.hasCompleted)
    }

    func saveValueProps(_ values: Set<String>) {
        defaults.set(Array(values).sorted(), forKey: Keys.valueProps)
    }

    func savedValueProps() -> Set<String> {
        Set(defaults.stringArray(forKey: Keys.valueProps) ?? [])
    }

    func saveDanceStyles(_ values: Set<String>) {
        defaults.set(Array(values).sorted(), forKey: Keys.danceStyles)
    }

    func savedDanceStyles() -> Set<String> {
        Set(defaults.stringArray(forKey: Keys.danceStyles) ?? [])
    }

    func saveVideoVolume(_ value: String?) {
        if let value {
            defaults.set(value, forKey: Keys.videoVolume)
        } else {
            defaults.removeObject(forKey: Keys.videoVolume)
        }
    }

    func savedVideoVolume() -> String? {
        defaults.string(forKey: Keys.videoVolume)
    }
}
