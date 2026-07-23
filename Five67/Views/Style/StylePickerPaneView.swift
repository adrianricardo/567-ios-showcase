import SwiftUI
import SwiftData

/// Styles tab. Lists every `Style`, lets the user pick the active one, add a
/// new custom style, or rename existing custom ones. Selecting a style changes
/// the active practice context, returns to Feed, and starts that style playing.
/// Defaults (Cumbia / Salsa / Bachata) are not renameable or deletable.
struct StylePickerPaneView: View {
    private enum PendingStyleAction {
        case select(UUID)
        case create
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore
    @Environment(AppRouter.self) private var router
    @Environment(UnlockStore.self) private var unlockStore
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @Query(sort: \Style.createdAt, order: .forward)
    private var styles: [Style]

    @State private var renameTarget: Style?
    @State private var showRenameSheet = false
    @State private var showAddSheet = false
    @State private var unlockPrompt: UnlockPromptReason?
    @State private var pendingStyleAction: PendingStyleAction?
    @State private var unlockSucceeded = false

    var body: some View {
        VStack(spacing: Spacing.none) {
            header
            content
            unlockFooter
        }
        .foregroundStyle(Theme.stagePrimary)
        .background(Theme.stageBackground)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRenameSheet) {
            if let style = renameTarget {
                RenameSheet(
                    title: "Rename Style",
                    isPresented: $showRenameSheet,
                    initial: style.name
                ) { newName in
                    style.name = newName
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RenameSheet(
                title: "New Style",
                isPresented: $showAddSheet,
                initial: ""
            ) { newName in
                let style = Style(name: newName)
                modelContext.insert(style)
                select(style)
            }
        }
        .sheet(item: $unlockPrompt, onDismiss: handleUnlockSheetDismiss) { reason in
            UnlockPaywallSheet(reason: reason) {
                unlockSucceeded = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Styles")
            .font(Typography.screenTitle)
            .tracking(-0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.md)
    }

    // MARK: - Content

    private var content: some View {
        List {
            allRow
            ForEach(styles) { style in
                styleRow(style)
            }
            addRow
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(Theme.stageBackground)
        .contentMargins(.bottom, Spacing.bottomBarClearance, for: .scrollContent)
    }

    private var allRow: some View {
        StyleSelectionList(
            styles: [],
            selectedStyleID: styleStore.activeStyle?.id,
            includesAllStyles: true,
            onSelect: { _ in select(nil) }
        )
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// The Styles tab keeps its own `List` so rows can carry swipe actions, but
    /// renders the same `StyleSelectionList` row for a single style so the tab
    /// and the two style sheets stay visually identical.
    private func styleRow(_ style: Style) -> some View {
        StyleSelectionList(
            styles: [style],
            selectedStyleID: styleStore.activeStyle?.id,
            onSelect: { _ in select(style) }
        )
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityActions {
            if !style.isDefault {
                Button("Rename") {
                    renameTarget = style
                    showRenameSheet = true
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !style.isDefault {
                Button {
                    renameTarget = style
                    showRenameSheet = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }

    private var addRow: some View {
        Button {
            requestStyleCreation()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.stagePrimary)
                Text("Add new style")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.stagePrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: Spacing.rowMinHeight)
            .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.stageBoundary(colorSchemeContrast), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func select(_ style: Style?) {
        guard unlockStore.canUseStyle(style?.id) else {
            if let style {
                pendingStyleAction = .select(style.id)
                unlockPrompt = .styleLimit
            }
            return
        }
        unlockStore.recordStyleUse(style?.id)
        styleStore.activeStyle = style
        Haptics.select()
        router.selectedTab = .feed
    }

    @ViewBuilder
    private var unlockFooter: some View {
        if !unlockStore.isUnlocked {
            Button {
                pendingStyleAction = nil
                unlockPrompt = .durableEntry
            } label: {
                Label("Unlock unlimited videos & styles", systemImage: "infinity")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.stagePrimary)
                    .padding(.vertical, Spacing.smPlus)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.bottomBarClearance)
        }
    }

    private func requestStyleCreation() {
        guard unlockStore.canUseStyle(UUID()) else {
            pendingStyleAction = .create
            unlockPrompt = .styleLimit
            return
        }
        showAddSheet = true
    }

    private func resumePendingStyleAction() {
        guard let action = pendingStyleAction else { return }
        pendingStyleAction = nil
        switch action {
        case .select(let styleID):
            if let style = styles.first(where: { $0.id == styleID }) {
                select(style)
            }
        case .create:
            showAddSheet = true
        }
    }

    private func handleUnlockSheetDismiss() {
        guard unlockSucceeded else { return }
        unlockSucceeded = false
        resumePendingStyleAction()
    }
}
