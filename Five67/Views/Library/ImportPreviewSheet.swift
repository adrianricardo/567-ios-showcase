import SwiftUI

struct ImportPreviewSheet: View {
    let newCount: Int
    let duplicateCount: Int
    let onContinue: () -> Void
    let onCancel: () -> Void
    @AccessibilityFocusState private var focusHeadline: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl2) {
                Spacer()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Theme.stageSecondary)
                        .accessibilityHidden(true)

                    VStack(spacing: Spacing.sm) {
                        Text(headline)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($focusHeadline)
                        if duplicateCount > 0 {
                            Text(duplicateLine)
                                .font(.body)
                                .foregroundStyle(Theme.stageSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl4)

                Spacer()

                Button(action: onContinue) {
                    Text(newCount == 0 ? "Done" : "Continue")
                }
                .buttonStyle(StagePrimaryActionButtonStyle())
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.md)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", action: onCancel)
                }
            }
            .foregroundStyle(Theme.stagePrimary)
            .background(Theme.stageBackground)
            .toolbarBackground(Theme.stageBackground, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await Task.yield()
            focusHeadline = true
        }
    }

    private var headline: String {
        switch newCount {
        case 0:  return "All videos already imported"
        case 1:  return "1 new video found"
        default: return "\(newCount) new videos found"
        }
    }

    private var duplicateLine: String {
        duplicateCount == 1
            ? "1 already imported"
            : "\(duplicateCount) already imported"
    }
}

#Preview("Mixed") {
    Text("host").sheet(isPresented: .constant(true)) {
        ImportPreviewSheet(newCount: 4, duplicateCount: 2, onContinue: {}, onCancel: {})
    }
}

#Preview("All duplicates") {
    Text("host").sheet(isPresented: .constant(true)) {
        ImportPreviewSheet(newCount: 0, duplicateCount: 3, onContinue: {}, onCancel: {})
    }
}
