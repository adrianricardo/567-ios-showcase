import SwiftUI

struct TimestampPill: View {
    let time: TimeInterval

    var body: some View {
        Text(formatTime(time))
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.smPlus)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(Color.black.opacity(0.55))
            )
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
            .background(
                Circle().fill(active ? Color.accentColor : Color.black.opacity(0.45))
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}
