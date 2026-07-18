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

    var title: String {
        switch self {
        case .onboarding, .durableEntry:
            "Pay once. Yours forever."
        case .videoLimit:
            "Keep building your library."
        case .styleLimit:
            "Unlock your second style?"
        }
    }

    var subtitle: String {
        switch self {
        case .onboarding, .durableEntry:
            "Unlock unlimited videos and styles — no subscription, ever."
        case .videoLimit:
            "Your free library includes 10 videos. Unlock unlimited videos and styles."
        case .styleLimit:
            "Your free library includes one dance style. Unlock every style and keep your choice."
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
    static let freeVideoLimit = 10

    // v1.0 was the last unlimited release. Its final repository state was build
    // 52; the shipping binary was built earlier, so <= 52 safely includes every
    // install that first downloaded a free/unlimited production build.
    static let lastLegacyBuildNumber = 52

    static func videoImportAllowance(
        accessLevel: AccessLevel,
        currentVideoCount: Int,
        requestedCount: Int
    ) -> VideoImportAllowance {
        guard requestedCount > 0 else {
            return VideoImportAllowance(allowedCount: 0, requiresUnlock: false)
        }
        guard !accessLevel.isUnlimited else {
            return VideoImportAllowance(allowedCount: requestedCount, requiresUnlock: false)
        }

        let remaining = max(0, freeVideoLimit - currentVideoCount)
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
