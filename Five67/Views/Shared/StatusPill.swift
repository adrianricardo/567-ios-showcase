import SwiftUI

struct StatusDot: View {
    let status: Status
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
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
    }
}
