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
        // Over-video chrome: always light-on-dark, never adapts to light/dark.
        // Active uses a frosted translucent-white fill with a dark glyph so the
        // glyph stays legible against the bright fill (a white glyph on the old
        // accent-washed fill was invisible).
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(active ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            .liquidGlass(
                in: Circle(),
                tint: active ? Color.white.opacity(0.85) : nil,
                interactive: true
            )
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}
