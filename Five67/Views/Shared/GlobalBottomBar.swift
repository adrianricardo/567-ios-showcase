import SwiftUI

/// Which surface the bottom bar is currently anchored to. Drives the selected
/// state of the three tab icons.
enum BottomBarActive {
    case library, feed, style
}

/// Persistent bottom chrome overlaying the feed and its side panes. A glass tab
/// capsule (Library · Feed · Style) plus a detached Add-Video glass button on
/// the right. The selection indicator is real Liquid Glass on iOS 26 and morphs
/// between tabs via `glassEffectID`; a sliding material pill is the fallback.
struct GlobalBottomBar: View {
    let active: BottomBarActive
    let onOpenLibrary: () -> Void
    let onShowFeed: () -> Void
    let onAddVideo: () -> Void
    let onOpenStyles: () -> Void

    /// Shared identity for the single selection indicator so it morphs (iOS 26)
    /// or slides (matchedGeometry fallback) from one tab to the next.
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.smPlus) {
            tabCapsule
            addButton
        }
        .padding(.horizontal, Spacing.mdPlus)
    }

    // MARK: - Tab capsule

    private var tabCapsule: some View {
        // GlassCluster groups the capsule's glass with the indicator's glass so,
        // on iOS 26, the selection morphs fluidly as it travels. Passthrough
        // below iOS 26.
        GlassCluster(spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                tabButton(
                    systemName: "photo.stack.fill",
                    accessibilityLabel: "Library",
                    isActive: active == .library,
                    action: onOpenLibrary
                )
                tabButton(
                    systemName: "play.rectangle.fill",
                    accessibilityLabel: "Feed",
                    isActive: active == .feed,
                    action: onShowFeed
                )
                tabButton(
                    systemName: "slider.horizontal.3",
                    accessibilityLabel: "Styles",
                    isActive: active == .style,
                    action: onOpenStyles
                )
            }
            .padding(Spacing.xsPlus)
            .liquidGlass(in: Capsule())
        }
        .shadow(color: .black.opacity(0.14), radius: 16, y: 4)
        .animation(selectionAnimation, value: active)
    }

    private func tabButton(
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
                // White when selected so the icon reads on top of the tinted
                // pill (accent-on-accent would vanish).
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                // Glass goes on the label itself (not a detached background) so
                // the press lands on it and the interactive lift can fire.
                .modifier(TabSelectionGlass(
                    isActive: isActive,
                    namespace: selection,
                    reduceMotion: reduceMotion
                ))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    /// Spring travel when motion is allowed; a gentle fade otherwise.
    private var selectionAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .snappy(duration: 0.38, extraBounce: 0.12)
    }

    // MARK: - Add Video (detached)

    private var addButton: some View {
        Button {
            onAddVideo()
            Haptics.light()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 64, height: 64)
                .padding(Spacing.xsPlus)
                .liquidGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add video")
        .shadow(color: .black.opacity(0.14), radius: 16, y: 4)
    }
}

/// Selected-tab glass. On iOS 26 the active tab's label becomes a tinted
/// **interactive** glass capsule — `.interactive()` gives the press-and-hold
/// lens lift, and `glassEffectID` lets the system morph it between tabs (clear
/// while travelling → tinted at rest). Below iOS 26 it's a solid-ish accent pill
/// slid via `matchedGeometryEffect`. Reduce Motion drops the shared identity so
/// it cross-fades in place instead of travelling.
private struct TabSelectionGlass: ViewModifier {
    let isActive: Bool
    let namespace: Namespace.ID
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if isActive {
                let glass = content
                    .glassEffect(.regular.tint(Color.accentColor).interactive(), in: Capsule())
                if reduceMotion {
                    glass.transition(.opacity)
                } else {
                    glass.glassEffectID("bottomBarSelection", in: namespace)
                }
            } else {
                content
            }
        } else {
            content.background {
                if isActive {
                    let pill = Capsule().fill(Color.accentColor.opacity(0.85))
                    if reduceMotion {
                        pill.transition(.opacity)
                    } else {
                        pill.matchedGeometryEffect(id: "bottomBarSelection", in: namespace)
                    }
                }
            }
        }
    }
}
