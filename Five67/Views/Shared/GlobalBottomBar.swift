import SwiftUI

/// Which surface the bottom bar is currently anchored to. Drives the tinted
/// state of the four icons.
enum BottomBarActive {
    case library, feed, style
}

/// Persistent bottom bar overlaying the feed and its side panes. Four icon
/// buttons, no labels: Library · Feed · Add Video · Style.
struct GlobalBottomBar: View {
    let active: BottomBarActive
    let onOpenLibrary: () -> Void
    let onShowFeed: () -> Void
    let onAddVideo: () -> Void
    let onOpenStyles: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            iconButton(
                systemName: "photo.stack.fill",
                accessibilityLabel: "Library",
                isActive: active == .library,
                action: onOpenLibrary
            )
            iconButton(
                systemName: "play.rectangle.fill",
                accessibilityLabel: "Feed",
                isActive: active == .feed,
                action: onShowFeed
            )
            iconButton(
                systemName: "plus.circle.fill",
                accessibilityLabel: "Add video",
                isActive: false,
                action: onAddVideo
            )
            iconButton(
                systemName: "slider.horizontal.3",
                accessibilityLabel: "Styles",
                isActive: active == .style,
                action: onOpenStyles
            )
        }
        .padding(Spacing.xsPlus)
        .liquidGlass(in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 16, y: 4)
        .padding(.horizontal, Spacing.mdPlus)
    }

    private func iconButton(
        systemName: String,
        accessibilityLabel: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            Haptics.light()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    Capsule()
                        .fill(isActive ? Color.accentColor.opacity(0.16) : Color.clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
