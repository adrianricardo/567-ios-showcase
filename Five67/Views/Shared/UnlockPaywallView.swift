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
        VStack(spacing: Spacing.xl4) {
            VStack(spacing: Spacing.md) {
                Text(reason.title)
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(reason.subtitle)
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                BulletLine("∞ Unlimited videos")
                BulletLine("🎨 Unlimited styles")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.stageSurface))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.stageStroke, lineWidth: 1)
            }

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

    @ViewBuilder
    private var statusMessages: some View {
        if let message = unlockStore.productLoadMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.stageSecondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(message)
                .accessibilityFocused($statusFocus, equals: .product)
        }

        if let message = unlockStore.purchaseMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.stageSecondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(message)
                .accessibilityFocused($statusFocus, equals: .purchase)
        }
    }

    private var unlockButtonTitle: String {
        if unlockStore.isPurchasing { return "Unlocking..." }
        if unlockStore.isLoadingProduct { return "Loading unlock..." }
        guard let displayPrice = unlockStore.displayPrice else { return "Unlock unavailable" }
        return "Unlock 567 — \(displayPrice)"
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
