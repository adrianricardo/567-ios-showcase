import SwiftUI

struct NowPlayingStripView: View {
    let move: Move
    let onTap: () -> Void

    private var displayName: String {
        move.name.isEmpty ? "Unnamed" : move.name
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.smPlus) {
                StatusDot(status: move.status)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(move.name.isEmpty ? Color.secondary : Color.primary)
                        .lineLimit(1)
                    Text(move.rangeLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: Spacing.xl3, height: Spacing.xl3)
            }
            .padding(.horizontal, Spacing.mdPlus)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}
