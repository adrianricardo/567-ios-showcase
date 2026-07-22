import Foundation

/// The one question onboarding asks. It is **session-only** by contract: the
/// answer shapes the tailored payoff copy and nothing else. It is never
/// persisted, exported, or treated as research/analytics data, which is why it
/// owns its copy here instead of being stored and looked up later.
enum OnboardingMotivation: String, CaseIterable, Identifiable {
    case remember
    case practice
    case organize

    var id: String { rawValue }

    /// Answer shown on the Motivation beat.
    var label: String {
        switch self {
        case .remember: "Remember moves when I'm out dancing"
        case .practice: "Practice what I learned between classes"
        case .organize: "Organize my class videos"
        }
    }

    /// Headline the Payoff beat adapts to.
    var payoffHeadline: String {
        switch self {
        case .remember: "See every move you've learned in one place."
        case .practice: "Loop the exact part until it sticks."
        case .organize: "Give every class video a home."
        }
    }

    var payoffSupportingCopy: String {
        switch self {
        case .remember: "Name a move once and it stays findable — no scrubbing through a whole class."
        case .practice: "Trim the section that matters and let it repeat while you drill it."
        case .organize: "Keep them organized by style instead of buried in Photos."
        }
    }
}
