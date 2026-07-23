import SwiftUI
import SwiftData

enum PaneTab: String, CaseIterable, Identifiable {
    case moves, videos
    var id: String { rawValue }
    var label: String {
        switch self {
        case .moves:  return "Moves"
        case .videos: return "Videos"
        }
    }
}

private struct PaneMoveGroup: Identifiable {
    let id: String
    let title: String
    let sortDate: Date
    let moves: [Move]
}

/// Library tab. Consolidates the Videos list and the Moves-grouped-by-video
/// list into one surface, scoped by the global style mode. Tapping a row hands
/// selection back to the feed via callbacks wired in RootView.
struct LibraryPaneView: View {
    private enum AccessibilityFocus: Hashable {
        case header
        case move(UUID)
        case video(UUID)
    }

    /// A quick-filter pick. `all` is distinct from "nothing was picked", which
    /// is why this isn't just an optional `Style`.
    private enum StyleFilterChoice {
        case all
        case style(Style)
    }

    let activeVideoID: UUID?
    let activeMoveID: UUID?
    let onSelectVideo: (Video) -> Void
    let onSelectMove: (Move) -> Void
    let onImportPhotos: () -> Void
    let onImportFiles: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(UnlockStore.self) private var unlockStore

    @Query(sort: [SortDescriptor(\Video.importedAt, order: .reverse)])
    private var allVideos: [Video]

    @Query(sort: \Style.createdAt, order: .forward) private var allStyles: [Style]

    @AppStorage("libraryPaneTab") private var tab: PaneTab = .moves
    @State private var search = ""
    @State private var showSettings = false
    @AccessibilityFocusState private var accessibilityFocus: AccessibilityFocus?

    @State private var deleteVideoTarget: Video?

    // Quick style filter. Selection is applied on dismiss so a style the free
    // tier can't use opens the paywall after this sheet is gone.
    @State private var showStylePicker = false
    @State private var styleFilterChoice: StyleFilterChoice?
    @State private var unlockPrompt: UnlockPromptReason?
    @State private var pendingFilterStyle: Style?
    @State private var unlockSucceeded = false

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var styleVideos: [Video] {
        allVideos.filter { styleStore.matches($0) }
    }

    private var searchedVideos: [Video] {
        guard !trimmedSearch.isEmpty else { return styleVideos }
        return styleVideos.filter { $0.displayName.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    private var moveGroups: [PaneMoveGroup] {
        var groups: [PaneMoveGroup] = []
        for video in styleVideos {
            let videoMatches = trimmedSearch.isEmpty
                || video.displayName.localizedCaseInsensitiveContains(trimmedSearch)
            let moves = video.movesSorted.filter { move in
                if trimmedSearch.isEmpty { return true }
                return videoMatches || move.name.localizedCaseInsensitiveContains(trimmedSearch)
            }
            guard !moves.isEmpty else { continue }
            groups.append(
                PaneMoveGroup(
                    id: video.id.uuidString,
                    title: groupTitle(for: video),
                    sortDate: video.recordedAt ?? video.importedAt,
                    moves: moves
                )
            )
        }
        return groups.sorted { $0.sortDate > $1.sortDate }
    }

    private var isEmpty: Bool { styleVideos.isEmpty }

    private var accentColor: Color {
        styleStore.accent?.color ?? Theme.stagePrimary
    }

    private var stageStroke: Color {
        Theme.stageBoundary(colorSchemeContrast)
    }

    var body: some View {
        VStack(spacing: Spacing.none) {
            libraryHeader
                .padding(.top, Spacing.lg)
            tabPicker
            searchField
            content
        }
        .foregroundStyle(Theme.stagePrimary)
        .background(Theme.stageBackground)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showSettings) {
            NavigationStack {
                LibrarySettingsView()
            }
        }
        .sheet(item: $deleteVideoTarget) { video in
            VideoDeleteSheet(video: video) { deleteVideo(video) }
        }
        .sheet(isPresented: $showStylePicker, onDismiss: handleStylePickerDismiss) {
            StyleSelectionSheet(
                context: .quickFilter,
                styles: allStyles,
                selectedStyleID: styleStore.activeStyle?.id,
                onSelect: { style in
                    styleFilterChoice = style.map(StyleFilterChoice.style) ?? .all
                }
            )
        }
        .sheet(item: $unlockPrompt, onDismiss: handleUnlockSheetDismiss) { reason in
            UnlockPaywallSheet(reason: reason) {
                unlockSucceeded = true
            }
        }
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Text("Library")
                .font(Typography.screenTitle)
                .tracking(-0.8)
                .accessibilityFocused($accessibilityFocus, equals: .header)

            Spacer()

            Button {
                Haptics.light()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.stagePrimary)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(Theme.stageSurface, in: Circle())
                    .overlay { Circle().stroke(stageStroke, lineWidth: 1) }
                    .contentShape(Circle())
            }
            .buttonStyle(StageSelectableRowButtonStyle())
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens library settings")

            Button {
                showStylePicker = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    if styleStore.activeStyle != nil {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                    }
                    Text(styleStore.label)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Theme.stagePrimary)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: Spacing.touchTarget)
                .background(Theme.stageSurface, in: Capsule())
                .overlay { Capsule().stroke(stageStroke, lineWidth: 1) }
                .contentShape(Capsule())
            }
            .buttonStyle(StageSelectableRowButtonStyle())
            .accessibilityLabel("Style filter")
            .accessibilityValue(styleStore.label)
            .accessibilityHint("Opens the style picker")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private var tabPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(PaneTab.allCases) { t in
                Button {
                    if reduceMotion {
                        tab = t
                    } else {
                        withAnimation(.snappy(duration: 0.24, extraBounce: 0.03)) {
                            tab = t
                        }
                    }
                } label: {
                    Text(t.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.stageSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.touchTarget)
                        .background(
                            tab == t ? Theme.stageRaisedSurface : Color.clear,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
                .accessibilityLabel(t.label)
                .accessibilityValue(tab == t ? "Selected" : "")
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .padding(Spacing.xs)
        .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(stageStroke, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.smPlus)
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.stageSecondary)
            TextField("Search moves and videos", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: search) { _, new in
                    if new.count > 80 { search = String(new.prefix(80)) }
                }
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.stageSecondary)
                }
                .buttonStyle(.plain)
                .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.mdPlus)
        .padding(.vertical, Spacing.smPlus)
        .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(stageStroke, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isEmpty {
            emptyState
        } else {
            ZStack {
                if tab == .moves {
                    movesList
                        .transition(modeTransition)
                } else {
                    videosList
                        .transition(modeTransition)
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.26), value: tab)
        }
    }

    private var modeTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return tab == .videos
            ? .asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading))
            : .asymmetric(insertion: .push(from: .leading), removal: .push(from: .trailing))
    }

    private var movesList: some View {
        List {
            ForEach(moveGroups) { group in
                Section {
                    ForEach(group.moves) { move in
                        MoveRowView(
                            move: move,
                            isActive: move.id == activeMoveID,
                            onTap: { onSelectMove(move) },
                            onDelete: { deleteMove(move) },
                            onRename: { newName in rename(move, to: newName) },
                            onExclude: { toggleExclude(move) },
                            accentColor: playbackAccent(for: move.video)
                        )
                        .accessibilityFocused($accessibilityFocus, equals: .move(move.id))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(stageStroke, lineWidth: 1)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(group.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.stageSecondary)
                        .textCase(nil)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
                }
                .listSectionSeparator(.hidden)
            }
            if moveGroups.isEmpty {
                ContentUnavailableView(
                    "No moves match",
                    systemImage: "music.note.list",
                    description: Text("Try a different filter, style, or search.")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(Spacing.sm)
        .scrollIndicators(.hidden)
        .contentMargins(.top, Spacing.none, for: .scrollContent)
        .contentMargins(.bottom, Spacing.bottomBarClearance, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.stageBackground)
    }

    private var videosList: some View {
        List {
            ForEach(searchedVideos) { video in
                Button {
                    onSelectVideo(video)
                } label: {
                    VideoRowView(
                        video: video,
                        isPlaying: video.id == activeVideoID,
                        accent: playbackAccent(for: video)
                    )
                    .foregroundStyle(Theme.stagePrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(stageStroke, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityValue(video.id == activeVideoID ? "Playing" : "")
                .accessibilityFocused($accessibilityFocus, equals: .video(video.id))
                .accessibilityAction(named: "Delete") {
                    deleteVideoTarget = video
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button {
                        deleteVideoTarget = video
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
            if searchedVideos.isEmpty {
                ContentUnavailableView(
                    "No videos match",
                    systemImage: "film.stack",
                    description: Text("Try a different style or search.")
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, Spacing.bottomBarClearance, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.stageBackground)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xl2) {
            Spacer(minLength: 0)
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Theme.stageSecondary)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xsPlus) {
                Text("Drop in a dance video")
                    .font(.title2.weight(.bold))
                Text("Import a practice video to start building your library.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: Spacing.md) {
                Button {
                    onImportPhotos()
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(StagePrimaryActionButtonStyle())
                Button {
                    onImportFiles()
                } label: {
                    Label("Import from Files", systemImage: "folder")
                }
                .buttonStyle(StageSecondaryActionButtonStyle())
            }
            .padding(.horizontal, Spacing.xl3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Move helpers

    private func groupTitle(for video: Video) -> String {
        let date = (video.recordedAt ?? video.importedAt).formatted(date: .long, time: .omitted)
        return "\(date) · \(video.style?.name ?? "Unsorted")"
    }

    private func playbackAccent(for video: Video?) -> Color {
        guard let video, let style = video.style else { return Theme.stagePrimary }
        return StyleAccentPalette.accent(forName: style.name, id: style.id)?.color ?? Theme.stagePrimary
    }

    private func rename(_ move: Move, to name: String) {
        move.name = name
        move.updatedAt = Date()
        Haptics.success()
    }

    private func toggleExclude(_ move: Move) {
        move.isExcluded.toggle()
        move.updatedAt = Date()
        Haptics.light()
    }

    private func deleteMove(_ move: Move) {
        guard let video = move.video else {
            modelContext.delete(move)
            Haptics.medium()
            return
        }
        let sorted = video.movesSorted
        let dur = video.duration
        if sorted.count > 1, let idx = sorted.firstIndex(where: { $0.id == move.id }) {
            if idx > 0 {
                sorted[idx - 1].endTime = move.endTime ?? dur
            } else {
                sorted[idx + 1].time = 0
            }
        }
        modelContext.delete(move)
        Haptics.medium()
    }

    private func deleteVideo(_ video: Video) {
        VideoDeletionService.delete(video, in: modelContext, unlockStore: unlockStore)
    }

    // MARK: - Quick style filter

    private func handleStylePickerDismiss() {
        guard let choice = styleFilterChoice else { return }
        styleFilterChoice = nil
        switch choice {
        case .all:
            applyStyleFilter(nil)
        case .style(let style):
            applyStyleFilter(style)
        }
    }

    /// Same access gate the Styles tab uses — a style the free tier can't reach
    /// routes to the canonical paywall instead of silently filtering.
    private func applyStyleFilter(_ style: Style?) {
        guard unlockStore.canUseStyle(style?.id) else {
            pendingFilterStyle = style
            unlockPrompt = .styleLimit
            return
        }
        unlockStore.recordStyleUse(style?.id)
        styleStore.activeStyle = style
        Haptics.select()
    }

    private func handleUnlockSheetDismiss() {
        guard unlockSucceeded else { return }
        unlockSucceeded = false
        let style = pendingFilterStyle
        pendingFilterStyle = nil
        applyStyleFilter(style)
    }
}
