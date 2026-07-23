import Foundation
import Observation
import StoreKit

enum UnlockProduct {
    static let id = "com.nopalstudio.five67.unlock"
}

@MainActor
@Observable final class UnlockStore {
    var product: Product?
    var isLoadingProduct = false
    var isPurchasing = false
    var isRestoring = false
    var productLoadMessage: String?
    var purchaseMessage: String?

    private(set) var hasPaidUnlock = false
    private(set) var legacyUnlimited: Bool
    private(set) var claimedFreeStyleID: UUID?

    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let forcedAccessLevel: AccessLevel?

    private enum Keys {
        static let legacyUnlimited = "access.legacyUnlimited"
        static let legacyEvaluationComplete = "access.legacyEvaluationComplete"
        static let legacyLibrarySnapshotRecorded = "access.legacyLibrarySnapshotRecorded"
        static let claimedFreeStyleID = "access.claimedFreeStyleID"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let uiTestAccessLevel: AccessLevel?
        if arguments.contains("-Five67UITestPaidAccess") {
            uiTestAccessLevel = .paid
        } else if arguments.contains("-Five67UITestLegacyAccess") {
            uiTestAccessLevel = .legacy
        } else if arguments.contains("-Five67UITestFreeAccess") {
            uiTestAccessLevel = .free
        } else {
            uiTestAccessLevel = nil
        }
#else
        let uiTestAccessLevel: AccessLevel? = nil
#endif
        forcedAccessLevel = uiTestAccessLevel
        legacyUnlimited = defaults.bool(forKey: Keys.legacyUnlimited)
#if DEBUG
        if forcedAccessLevel == .free {
            let claimedFixtureStyle = arguments.contains("-Five67UITestClaimSalsaStyle")
                ? Style.Default.salsa
                : nil
            claimedFreeStyleID = claimedFixtureStyle
            defaults.set(claimedFixtureStyle?.uuidString, forKey: Keys.claimedFreeStyleID)
            return
        }
#endif
        claimedFreeStyleID = defaults.string(forKey: Keys.claimedFreeStyleID)
            .flatMap(UUID.init(uuidString:))
    }

    var accessLevel: AccessLevel {
        if let forcedAccessLevel { return forcedAccessLevel }
        if legacyUnlimited { return .legacy }
        if hasPaidUnlock { return .paid }
        return .free
    }

    var isUnlocked: Bool {
        accessLevel.isUnlimited
    }

    var displayPrice: String? {
        product?.displayPrice
    }

    var canPurchase: Bool {
        product != nil && !isLoadingProduct && !isPurchasing
    }

    func start(existingLibraryCount: Int) {
        guard transactionUpdatesTask == nil else { return }
        guard forcedAccessLevel == nil else { return }

        evaluateLegacyAccess(
            existingLibraryCount: existingLibraryCount,
            installEvidence: nil
        )

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.apply(transactionResult: result, finish: true)
            }
        }

        Task {
            await refreshEntitlements()
            await evaluateAppTransactionForLegacyAccess(existingLibraryCount: existingLibraryCount)
            await loadProduct()
        }
    }

    func videoImportAllowance(personalVideoCount: Int, requestedCount: Int) -> VideoImportAllowance {
        AccessPolicy.videoImportAllowance(
            accessLevel: accessLevel,
            personalVideoCount: personalVideoCount,
            requestedCount: requestedCount
        )
    }

    func canUseStyle(_ styleID: UUID?) -> Bool {
        AccessPolicy.canUseStyle(
            accessLevel: accessLevel,
            claimedFreeStyleID: claimedFreeStyleID,
            requestedStyleID: styleID
        )
    }

    func recordStyleUse(_ styleID: UUID?) {
        guard accessLevel == .free, claimedFreeStyleID == nil, let styleID else { return }
        claimedFreeStyleID = styleID
        defaults.set(styleID.uuidString, forKey: Keys.claimedFreeStyleID)
    }

    /// Keeps the free-style claim in sync with the personal library. When the
    /// last personal video is removed the claim is cleared, so the next styled
    /// personal video establishes a fresh free style. Demo content is excluded
    /// The claim is cleared once the user's library becomes empty.
    func recountPersonalVideos(_ personalVideoCount: Int) {
        guard personalVideoCount == 0 else { return }
        guard claimedFreeStyleID != nil else { return }
        claimedFreeStyleID = nil
        defaults.removeObject(forKey: Keys.claimedFreeStyleID)
    }

    func loadProduct() async {
        isLoadingProduct = true
        productLoadMessage = nil
        defer { isLoadingProduct = false }

        do {
            product = try await Product.products(for: [UnlockProduct.id]).first
            if product == nil {
                productLoadMessage = "Unlock is unavailable right now. You can keep using 567 free."
            }
        } catch {
            product = nil
            productLoadMessage = "Unlock is unavailable right now. You can keep using 567 free."
        }
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product else {
            productLoadMessage = "Unlock is unavailable right now. You can keep using 567 free."
            return false
        }

        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await apply(transactionResult: verification, finish: true)
                return hasPaidUnlock
            case .pending:
                apply(purchaseOutcome: .pending)
                return false
            case .userCancelled:
                apply(purchaseOutcome: .cancelled)
                return false
            @unknown default:
                return false
            }
        } catch StoreKitError.userCancelled {
            apply(purchaseOutcome: .cancelled)
            return false
        } catch {
            apply(purchaseOutcome: .failed)
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        isRestoring = true
        purchaseMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !hasPaidUnlock {
                purchaseMessage = "No unlock purchase found."
            }
            return hasPaidUnlock
        } catch {
            purchaseMessage = "Restore failed. Try again when you're online."
            return false
        }
    }

    func refreshEntitlements() async {
        var hasUnlock = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result) else { continue }
            guard transaction.productID == UnlockProduct.id else { continue }
            guard transaction.revocationDate == nil else { continue }
            hasUnlock = true
        }
        apply(purchaseOutcome: .verified(active: hasUnlock))
    }

    private func apply(
        transactionResult result: VerificationResult<StoreKit.Transaction>,
        finish: Bool
    ) async {
        guard let transaction = verifiedTransaction(from: result) else {
            apply(purchaseOutcome: .unverified)
            return
        }
        guard transaction.productID == UnlockProduct.id else { return }

        apply(purchaseOutcome: .verified(active: transaction.revocationDate == nil))
        if finish {
            await transaction.finish()
        }
    }

    private func verifiedTransaction(
        from result: VerificationResult<StoreKit.Transaction>
    ) -> StoreKit.Transaction? {
        switch result {
        case .verified(let transaction):
            transaction
        case .unverified:
            nil
        }
    }

    private func apply(purchaseOutcome: UnlockPurchaseOutcome) {
        let resolution = AccessPolicy.purchaseResolution(for: purchaseOutcome)
        if let paidAccessOverride = resolution.paidAccessOverride {
            hasPaidUnlock = paidAccessOverride
        }
        purchaseMessage = resolution.message
    }

    func evaluateLegacyAccess(
        existingLibraryCount: Int,
        installEvidence: AppInstallEvidence?
    ) {
        guard !legacyUnlimited else { return }
        guard !defaults.bool(forKey: Keys.legacyEvaluationComplete) else { return }

        let isInitialLibrarySnapshot = !defaults.bool(
            forKey: Keys.legacyLibrarySnapshotRecorded
        )
        if isInitialLibrarySnapshot {
            defaults.set(true, forKey: Keys.legacyLibrarySnapshotRecorded)
        }

        let shouldGrant = AccessPolicy.shouldGrantLegacyUnlimited(
            existingLibraryCount: isInitialLibrarySnapshot ? existingLibraryCount : 0,
            installEvidence: installEvidence
        )
        if shouldGrant {
            persistLegacyUnlimited()
        } else if installEvidence != nil {
            // A verified app transaction is the durable new-vs-legacy decision.
            // Once a new install is resolved, later user-created library content
            // must not accidentally turn that free user into a legacy install.
            defaults.set(true, forKey: Keys.legacyEvaluationComplete)
        }
    }

    private func evaluateAppTransactionForLegacyAccess(existingLibraryCount: Int) async {
#if targetEnvironment(simulator)
        // A raw Simulator install has no production app transaction. Asking for
        // one makes StoreKit attempt an interactive receipt renewal at launch.
        let automaticLookupAllowed = false
#else
        let automaticLookupAllowed = true
#endif
        guard AccessPolicy.shouldRequestLegacyAppTransaction(
            hasLegacyUnlimited: legacyUnlimited,
            legacyEvaluationComplete: defaults.bool(forKey: Keys.legacyEvaluationComplete),
            automaticLookupAllowed: automaticLookupAllowed
        ) else { return }

        do {
            let result = try await AppTransaction.shared
            guard case .verified(let appTransaction) = result else { return }
            let evidence = AppInstallEvidence(
                environment: installEnvironment(appTransaction.environment),
                originalBuildVersion: appTransaction.originalAppVersion
            )
            evaluateLegacyAccess(
                existingLibraryCount: existingLibraryCount,
                installEvidence: evidence
            )
        } catch {
            // Retry on a future launch. A transient App Store/network failure
            // must not permanently decide that an empty-library legacy user is new.
        }
    }

    private func persistLegacyUnlimited() {
        legacyUnlimited = true
        defaults.set(true, forKey: Keys.legacyUnlimited)
        defaults.set(true, forKey: Keys.legacyEvaluationComplete)
        defaults.set(true, forKey: Keys.legacyLibrarySnapshotRecorded)
    }

    private func installEnvironment(_ environment: AppStore.Environment) -> AppInstallEnvironment {
        switch environment {
        case .production:
            .production
        case .sandbox:
            .sandbox
        case .xcode:
            .xcode
        default:
            .unknown
        }
    }
}
