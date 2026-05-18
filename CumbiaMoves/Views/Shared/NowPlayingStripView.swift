import SwiftUI

struct NowPlayingStripView: View {
    let move: Move
    let onTap: () -> Void

    private var displayName: String {
        move.name.isEmpty ? "Unnamed segment" : move.name
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                StatusDot(status: move.status)

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
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
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}
