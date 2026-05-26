import SwiftUI

struct TimestampPill: View {
    let time: TimeInterval

    var body: some View {
        Text(formatTime(time))
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.smPlus)
            .padding(.vertical, Spacing.xs)
            .liquidGlass(in: Capsule())
    }
}

struct RailIcon: View {
    let systemName: String
    var active: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(active ? Color.white : Color.white.opacity(0.95))
            .frame(width: Spacing.xl5, height: Spacing.xl5)
            .liquidGlass(
                in: Circle(),
                tint: active ? Color.accentColor : nil,
                interactive: true
            )
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}
