import Foundation

enum AccessLevel: Equatable {
    case free
    case paid
    case legacy

    var isUnlimited: Bool {
        self != .free
    }
}

enum UnlockPromptReason: String, Identifiable {
    case onboarding
    case videoLimit
    case styleLimit
    case durableEntry

    var id: String { rawValue }

    /// Why *this* user is seeing the paywall. The headline is universal and
    /// owned by `UnlockPaywallView`; only this reason-specific line varies, and
    /// it reads below the headline.
    var explanation: String {
        switch self {
        case .onboarding, .durableEntry:
            "One payment. No subscription, ever."
        case .videoLimit:
            "Your free library includes \(AccessPolicy.freeVideoLimit) videos."
        case .styleLimit:
            "Your free library includes one dance style."
        }
    }
}

struct VideoImportAllowance: Equatable {
    let allowedCount: Int
    let requiresUnlock: Bool
}

enum AppInstallEnvironment: Equatable {
    case production
    case sandbox
    case xcode
    case unknown
}

struct AppInstallEvidence: Equatable {
    let environment: AppInstallEnvironment
    let originalBuildVersion: String
}

enum UnlockPurchaseOutcome: Equatable {
    case verified(active: Bool)
    case pending
    case cancelled
    case unverified
    case failed
}

struct UnlockPurchaseResolution: Equatable {
    let paidAccessOverride: Bool?
    let message: String?
}

enum AccessPolicy {
    /// Free installs may keep this many personal videos.
    static let freeVideoLimit = 3

    // v1.0 was the last unlimited release. Its final repository state was build
    // 52; the shipping binary was built earlier, so <= 52 safely includes every
    // install that first downloaded a free/unlimited production build.
    static let lastLegacyBuildNumber = 52

    /// AppTransaction can fall back to an interactive receipt renewal when its
    /// signed app transaction is unavailable. Startup must not trigger that
    /// Apple Account prompt, so callers disable this lookup in environments
    /// that cannot provide production app-transaction history silently.
    static func shouldRequestLegacyAppTransaction(
        hasLegacyUnlimited: Bool,
        legacyEvaluationComplete: Bool,
        automaticLookupAllowed: Bool
    ) -> Bool {
        !hasLegacyUnlimited && !legacyEvaluationComplete && automaticLookupAllowed
    }

    static func videoImportAllowance(
        accessLevel: AccessLevel,
        personalVideoCount: Int,
        requestedCount: Int
    ) -> VideoImportAllowance {
        guard requestedCount > 0 else {
            return VideoImportAllowance(allowedCount: 0, requiresUnlock: false)
        }
        guard !accessLevel.isUnlimited else {
            return VideoImportAllowance(allowedCount: requestedCount, requiresUnlock: false)
        }

        let remaining = max(0, freeVideoLimit - personalVideoCount)
        return VideoImportAllowance(
            allowedCount: min(remaining, requestedCount),
            requiresUnlock: requestedCount > remaining
        )
    }

    static func canUseStyle(
        accessLevel: AccessLevel,
        claimedFreeStyleID: UUID?,
        requestedStyleID: UUID?
    ) -> Bool {
        guard let requestedStyleID else { return true }
        guard !accessLevel.isUnlimited else { return true }
        guard let claimedFreeStyleID else { return true }
        return claimedFreeStyleID == requestedStyleID
    }

    static func shouldGrantLegacyUnlimited(
        existingLibraryCount: Int,
        installEvidence: AppInstallEvidence?
    ) -> Bool {
        if existingLibraryCount > 0 {
            return true
        }
        guard let installEvidence, installEvidence.environment == .production else {
            return false
        }
        guard let originalBuild = numericBuildVersion(installEvidence.originalBuildVersion) else {
            return false
        }
        return originalBuild <= lastLegacyBuildNumber
    }

    static func purchaseResolution(for outcome: UnlockPurchaseOutcome) -> UnlockPurchaseResolution {
        switch outcome {
        case .verified(let active):
            UnlockPurchaseResolution(paidAccessOverride: active, message: nil)
        case .pending:
            UnlockPurchaseResolution(
                paidAccessOverride: nil,
                message: "Purchase pending approval."
            )
        case .cancelled:
            UnlockPurchaseResolution(paidAccessOverride: nil, message: nil)
        case .unverified:
            UnlockPurchaseResolution(
                paidAccessOverride: nil,
                message: "We couldn't verify that purchase."
            )
        case .failed:
            UnlockPurchaseResolution(
                paidAccessOverride: nil,
                message: "Purchase failed. Try again when you're online."
            )
        }
    }

    private static func numericBuildVersion(_ rawValue: String) -> Int? {
        let leadingDigits = rawValue.prefix { $0.isNumber }
        guard !leadingDigits.isEmpty else { return nil }
        return Int(leadingDigits)
    }
}
