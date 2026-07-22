import SwiftUI
import UIKit

struct UnlockPaywallView: View {
    private enum StatusFocus: Hashable {
        case product
        case purchase
    }

    @Environment(UnlockStore.self) private var unlockStore
    @AccessibilityFocusState private var statusFocus: StatusFocus?

    let reason: UnlockPromptReason
    let secondaryTitle: String
    let onUnlocked: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl4) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Unlock unlimited videos & styles.")
                    .font(.largeTitle.weight(.heavy))
                    .fixedSize(horizontal: false, vertical: true)
                Text(reason.explanation)
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Open rows: no enclosing card, no strokes — the type carries it.
            VStack(alignment: .leading, spacing: Spacing.lg) {
                benefitRow(
                    "Unlimited videos",
                    "Keep every class you film, not just your first few."
                )
                benefitRow(
                    "Unlimited dance styles",
                    "Tag each video with the style it actually belongs to."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusMessages

            VStack(spacing: Spacing.md) {
                Button(unlockButtonTitle) {
                    Task { await purchase() }
                }
                .buttonStyle(StagePrimaryActionButtonStyle())
                .disabled(!unlockStore.canPurchase)

                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(StageSecondaryActionButtonStyle())

                Button("Restore purchase") {
                    Task { await restore() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.stageSecondary)
                .frame(minHeight: Spacing.touchTarget)
                .disabled(unlockStore.isRestoring)
            }
        }
        .task {
            if unlockStore.product == nil {
                await unlockStore.loadProduct()
            }
        }
        .onChange(of: unlockStore.productLoadMessage) { _, message in
            if message != nil {
                statusFocus = .product
            }
        }
        .onChange(of: unlockStore.purchaseMessage) { _, message in
            if message != nil {
                statusFocus = .purchase
            }
        }
    }

    private func benefitRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.stageSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusMessages: some View {
        if let message = unlockStore.productLoadMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.stageSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(message)
                .accessibilityFocused($statusFocus, equals: .product)
        }

        if let message = unlockStore.purchaseMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.stageSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(message)
                .accessibilityFocused($statusFocus, equals: .purchase)
        }
    }

    private var unlockButtonTitle: String {
        if unlockStore.isPurchasing { return "Unlocking..." }
        if unlockStore.isLoadingProduct { return "Loading unlock..." }
        // Never invent a price: without a loaded product there is nothing
        // honest to put after "Pay once".
        guard let displayPrice = unlockStore.displayPrice else { return "Unlock unavailable" }
        return "Pay once — \(displayPrice)"
    }

    private func purchase() async {
        if await unlockStore.purchase() {
            announceUnlock()
            onUnlocked()
        }
    }

    private func restore() async {
        if await unlockStore.restore() {
            announceUnlock()
            onUnlocked()
        }
    }

    private func announceUnlock() {
        UIAccessibility.post(
            notification: .announcement,
            argument: "567 is unlocked. Unlimited videos and styles are available."
        )
    }
}

struct UnlockPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss

    let reason: UnlockPromptReason
    let onUnlocked: () -> Void

    var body: some View {
        ScrollView {
            UnlockPaywallView(
                reason: reason,
                secondaryTitle: "Not now",
                onUnlocked: {
                    dismiss()
                    onUnlocked()
                },
                onSecondary: { dismiss() }
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xl4)
        }
        .foregroundStyle(Theme.stagePrimary)
        .background(Theme.stageBackground)
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}
