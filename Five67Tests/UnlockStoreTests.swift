import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Five67

private final class StoreKitTestBundleToken {}

// iOS 26.4's simulator runtime fails SKTestSession mutations from xcodebuild
// with SKInternalErrorDomain Code=3 (Apple FB22237318 / FB22774836). Keep the
// real StoreKit suite available for Xcode IDE runs and newer fixed runtimes
// without making the repository's normal test command hang on this toolchain.
@Suite(
    "Lifetime unlock StoreKit behavior",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["FIVE67_RUN_STOREKIT_TESTS"] == "1")
)
@MainActor
struct UnlockStoreTests {
    @Test func productLoadsWithLocalizedPrice() async throws {
        _ = try makeSession()
        let store = UnlockStore(defaults: try makeDefaults())

        await store.loadProduct()

        #expect(store.product?.id == UnlockProduct.id)
        #expect(store.displayPrice == "$6.99")
        #expect(store.canPurchase)
    }

    @Test func successfulPurchaseUnlocksImmediately() async throws {
        _ = try makeSession()
        let store = UnlockStore(defaults: try makeDefaults())
        await store.loadProduct()

        let purchased = await store.purchase()

        #expect(purchased)
        #expect(store.accessLevel == .paid)
        #expect(store.purchaseMessage == nil)
    }

    @Test func cancellationKeepsFreeAccessWithoutFalseError() async throws {
        let session = try makeSession()
        try await session.setSimulatedError(
            .generic(.userCancelled),
            forAPI: .purchase
        )
        let store = UnlockStore(defaults: try makeDefaults())
        await store.loadProduct()

        let purchased = await store.purchase()

        #expect(!purchased)
        #expect(store.accessLevel == .free)
        #expect(store.purchaseMessage == nil)
    }

    @Test func askToBuyLeavesAccessFreeAndExplainsPendingState() async throws {
        let session = try makeSession()
        session.askToBuyEnabled = true
        let store = UnlockStore(defaults: try makeDefaults())
        await store.loadProduct()

        let purchased = await store.purchase()

        #expect(!purchased)
        #expect(store.accessLevel == .free)
        #expect(store.purchaseMessage == "Purchase pending approval.")
    }

    @Test func failedPurchaseLeavesAccessFree() async throws {
        let session = try makeSession()
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))),
            forAPI: .purchase
        )
        let store = UnlockStore(defaults: try makeDefaults())
        await store.loadProduct()

        let purchased = await store.purchase()

        #expect(!purchased)
        #expect(store.accessLevel == .free)
        #expect(store.purchaseMessage == "Purchase failed. Try again when you're online.")
    }

    @Test func unverifiedPurchaseLeavesAccessFree() async throws {
        let session = try makeSession()
        try await session.setSimulatedError(
            .verification(.invalidSignature),
            forAPI: .verification
        )
        let store = UnlockStore(defaults: try makeDefaults())
        await store.loadProduct()

        let purchased = await store.purchase()

        #expect(!purchased)
        #expect(store.accessLevel == .free)
        #expect(store.purchaseMessage == "We couldn't verify that purchase.")
    }

    @Test func currentEntitlementRestoresAfterStoreRelaunch() async throws {
        let session = try makeSession()
        _ = try await session.buyProduct(identifier: UnlockProduct.id)
        let store = UnlockStore(defaults: try makeDefaults())

        await store.refreshEntitlements()

        #expect(store.accessLevel == .paid)
    }

    @Test func restoreFindsPurchaseWithoutLocalPaidState() async throws {
        let session = try makeSession()
        _ = try await session.buyProduct(identifier: UnlockProduct.id)
        let store = UnlockStore(defaults: try makeDefaults())

        let restored = await store.restore()

        #expect(restored)
        #expect(store.accessLevel == .paid)
        #expect(store.purchaseMessage == nil)
    }

    @Test func restoreNoneIsUnderstandable() async throws {
        _ = try makeSession()
        let store = UnlockStore(defaults: try makeDefaults())

        let restored = await store.restore()

        #expect(!restored)
        #expect(store.accessLevel == .free)
        #expect(store.purchaseMessage == "No unlock purchase found.")
    }

    @Test func refundedPurchaseRemovesPaidAccessButPreservesLegacyAccess() async throws {
        let session = try makeSession()
        let transaction = try await session.buyProduct(identifier: UnlockProduct.id)
        let paidStore = UnlockStore(defaults: try makeDefaults())
        await paidStore.refreshEntitlements()
        #expect(paidStore.accessLevel == .paid)

        let testTransaction = try #require(
            session.allTransactions().first {
                $0.productIdentifier == transaction.productID
            }
        )
        try session.refundTransaction(identifier: testTransaction.identifier)
        for _ in 0..<20 {
            await paidStore.refreshEntitlements()
            if paidStore.accessLevel == .free { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(paidStore.accessLevel == .free)

        let legacyStore = UnlockStore(defaults: try makeDefaults())
        legacyStore.evaluateLegacyAccess(existingLibraryCount: 1, installEvidence: nil)
        await legacyStore.refreshEntitlements()
        #expect(legacyStore.accessLevel == .legacy)
    }

    @Test func productUnavailableDoesNotInventAPrice() async throws {
        let session = try makeSession()
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))),
            forAPI: .loadProducts
        )
        let store = UnlockStore(defaults: try makeDefaults())

        await store.loadProduct()

        #expect(store.product == nil)
        #expect(store.displayPrice == nil)
        #expect(!store.canPurchase)
        #expect(store.productLoadMessage == "Unlock is unavailable right now. You can keep using 567 free.")
    }

    private func makeSession() throws -> SKTestSession {
        let configurationURL = try #require(
            Bundle(for: StoreKitTestBundleToken.self).url(
                forResource: "Five67Tests",
                withExtension: "storekit"
            )
        )
        let session = try SKTestSession(contentsOf: configurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "UnlockStoreTests-\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: suiteName))
    }
}
