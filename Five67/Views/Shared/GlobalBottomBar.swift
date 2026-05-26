import SwiftUI

/// Persistent bottom bar overlaying both Library and Feed (iOS Photos pattern).
/// Left pill: Library | Feed segmented tabs.
/// Right circle: current style filter; tap opens a style picker menu.
struct GlobalBottomBar: View {
    @Binding var selection: AppTab
    @Bindable var styleStore: StyleStore

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.none) {
            tabPill
            Spacer(minLength: 0)
            styleChip
        }
        .padding(.horizontal, Spacing.mdPlus)
    }

    // MARK: - Tab pill

    private var tabPill: some View {
        HStack(spacing: Spacing.xs) {
            tabButton(.library, label: "Library", systemImage: "photo.stack.fill")
            tabButton(.feed, label: "Feed", systemImage: "play.rectangle.fill")
        }
        .padding(Spacing.xsPlus)
        .liquidGlass(in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 16, y: 4)
    }

    private func tabButton(_ tab: AppTab, label: String, systemImage: String) -> some View {
        let isActive = selection == tab
        return Button {
            guard selection != tab else { return }
            selection = tab
            Haptics.light()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .frame(width: 104, height: 64)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    // MARK: - Style chip (right circle)

    private var styleChip: some View {
        Menu {
            Picker("Style", selection: $styleStore.activeStyle) {
                Text("All").tag(DanceStyle?.none)
                ForEach(DanceStyle.allCases) { style in
                    Text(style.label).tag(DanceStyle?.some(style))
                }
            }
        } label: {
            Text(styleStore.label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 76, height: 76)
                .liquidGlass(in: Circle(), interactive: true)
                .shadow(color: .black.opacity(0.14), radius: 16, y: 4)
        }
        .accessibilityLabel("Style: \(styleStore.label)")
    }
}
