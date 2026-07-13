import Foundation
import Observation
import StoreKit

enum UnlockProduct {
    static let id = "com.nopalstudio.five67.unlock"
}

@MainActor
@Observable final class UnlockStore {
    var product: Product?
    var isUnlocked = false
    var isLoadingProduct = false
    var isPurchasing = false
    var isRestoring = false
    var productLoadMessage: String?
    var purchaseMessage: String?

    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var displayPrice: String {
        product?.displayPrice ?? "$6.99"
    }

    var canPurchase: Bool {
        product != nil && !isLoadingProduct && !isPurchasing
    }

    func start() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.apply(transactionResult: result, finish: true)
            }
        }

        Task {
            await refreshEntitlements()
            await loadProduct()
        }
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
                return isUnlocked
            case .pending:
                purchaseMessage = "Purchase pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseMessage = "Purchase failed. Try again when you're online."
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
            if !isUnlocked {
                purchaseMessage = "No unlock purchase found."
            }
            return isUnlocked
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
        isUnlocked = hasUnlock
    }

    private func apply(
        transactionResult result: VerificationResult<StoreKit.Transaction>,
        finish: Bool
    ) async {
        guard let transaction = verifiedTransaction(from: result) else {
            purchaseMessage = "We couldn't verify that purchase."
            return
        }
        guard transaction.productID == UnlockProduct.id else { return }

        isUnlocked = transaction.revocationDate == nil
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
}
