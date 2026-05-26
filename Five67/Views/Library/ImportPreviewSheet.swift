import SwiftUI

struct ImportPreviewSheet: View {
    let newCount: Int
    let duplicateCount: Int
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl2) {
                Spacer()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.tint)

                    VStack(spacing: Spacing.sm) {
                        Text(headline)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        if duplicateCount > 0 {
                            Text(duplicateLine)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl4)

                Spacer()

                Button(action: onContinue) {
                    Text(newCount == 0 ? "Done" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.primaryButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.md)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", action: onCancel)
                }
            }
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
