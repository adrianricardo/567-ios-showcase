import SwiftUI

struct StatusDot: View {
    let status: Status
    var size: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().fill(status.color)
            if status != .empty {
                Image(systemName: status == .mastered ? "checkmark" : "exclamationmark")
                    .font(.system(size: max(6, size * 0.58), weight: .black))
                    .foregroundStyle(.black.opacity(0.78))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Status")
        .accessibilityValue(status.displayName)
    }
}

struct StatusBadge: View {
    let status: Status

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
            .accessibilityLabel("Status")
            .accessibilityValue(status.displayName)
    }
}
