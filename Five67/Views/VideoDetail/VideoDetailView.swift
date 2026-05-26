import SwiftUI
import SwiftData
import OSLog

struct VideoDetailView: View {
    let video: Video
    let startTime: TimeInterval?
    let onFinish: ((TimeInterval?) -> Void)?
    @State private var controller: PlaybackController
    @State private var activeMoveID: UUID?
    @State private var sortedMoves: [Move] = []
    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var didApplyStartTime = false
    // Start time of the most recently marked move during this editor session.
    // Reported back to the caller on Done so the feed can re-open on the new
    // move's first frame. Nil means the user didn't mark anything → caller
    // should keep its existing restore behavior.
    @State private var lastMarkedTime: TimeInterval?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @Query(sort: \Style.createdAt, order: .forward) private var allStyles: [Style]

    private let logger = Logger(subsystem: "Five67", category: "VideoDetail")

    init(
        video: Video,
        startTime: TimeInterval? = nil,
        onFinish: ((TimeInterval?) -> Void)? = nil
    ) {
        self.video = video
        self.startTime = startTime
        self.onFinish = onFinish
        self._controller = State(wrappedValue: PlaybackController(videoURL: video.fileURL))
        self._sortedMoves = State(wrappedValue: video.movesSorted)
    }

    private var activeMove: Move? {
        guard let id = activeMoveID else { return nil }
        return sortedMoves.first { $0.id == id }
    }

    private var hasMoves: Bool { !sortedMoves.isEmpty }

    var body: some View {
        contentList
            .environment(controller)
            .safeAreaInset(edge: .top, spacing: 0) {
                heroSection
            }
            .onChange(of: controller.currentTime) { _, t in
                advanceActiveMove(currentTime: t)
            }
            .onChange(of: video.moves.count) {
                refreshSortedMoves()
            }
            .onAppear {
                refreshSortedMoves()
                // Land the editor where the feed left off, when handed a
                // start time. Guarded so we only honor it on the first
                // appearance (re-appearances after dismiss don't re-seek).
                if !didApplyStartTime, let t = startTime, t.isFinite, t > 0 {
                    controller.seek(to: t)
                }
                didApplyStartTime = true
                controller.play()
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showRename) {
                RenameSheet(
                    title: "Rename Video",
                    isPresented: $showRename,
                    initial: video.displayName
                ) { newName in
                    video.displayName = newName
                }
            }
            .confirmationDialog(
                "Delete \"\(video.displayName)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Video & All Moves", role: .destructive) {
                    deleteCurrentVideo()
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: Spacing.none) {
            topBar
            VideoHeroView(
                controller: controller,
                video: video,
                moves: sortedMoves,
                allowsMarkerEditing: true,
                showsPlaceholderWhenEmpty: true
            ) {
                VStack(spacing: Spacing.mdPlus) {
                    videoMenu
                    MuteRailButton()
                    LoopRailButton(controller: controller)
                    SplitRailButton(controller: controller, onSplit: split)
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            Button { finishEditing() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            }
            .accessibilityLabel("Back")

            Spacer(minLength: 0)

            Text(video.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            // Balance the leading back button so the title stays centered.
            Color.clear.frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: Spacing.touchTarget)
        .background(Color.black)
    }

    private var videoMenu: some View {
        Menu {
            Picker("Style", selection: styleBinding) {
                ForEach(allStyles) { style in
                    Text(style.name).tag(UUID?.some(style.id))
                }
            }
            Button {
                showRename = true
            } label: {
                Label("Rename Video", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Video", systemImage: "trash")
            }
        } label: {
            RailIcon(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    /// Picker is bound to the *id* rather than the `Style` itself so SwiftUI
    /// has a stable, `Hashable` tag value (a `Style` reference would need
    /// careful tag identity across re-fetches).
    private var styleBinding: Binding<UUID?> {
        Binding(
            get: { video.style?.id },
            set: { newID in
                video.style = newID.flatMap { id in allStyles.first(where: { $0.id == id }) }
            }
        )
    }

    @ViewBuilder
    private var contentList: some View {
        if hasMoves {
            List {
                ForEach(sortedMoves) { move in
                    MoveRowView(
                        move: move,
                        isActive: activeMoveID == move.id,
                        onTap: { activateMove(move) },
                        onDelete: { deleteMove(move) },
                        onRename: { newName in renameMove(move, to: newName) },
                        onExclude: { toggleExclude(move) }
                    )
                    .id(move.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.plain)
        } else {
            emptyMovesHint
        }
    }

    /// Inline coach shown when the video has no moves yet. The scissor icon
    /// is a real Button that calls `split()` so users can tap either the rail
    /// button above or this hint copy — whichever they reached for first.
    private var emptyMovesHint: some View {
        VStack {
            Spacer(minLength: 0)
            HStack(spacing: Spacing.smPlus) {
                Text("Press")
                Button {
                    split()
                } label: {
                    RailIcon(systemName: "scissors")
                }
                .disabled(controller.duration == 0)
                .accessibilityLabel("Split")
                Text("to add your first move")
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xl2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The feed's GlobalBottomBar overlays the bottom ~92pt of this view
        // (the editor is pushed inside the feed's NavigationStack). Balance
        // the centering by reserving that area at the bottom so the hint
        // sits in the middle of the *visible* region, not the full frame.
        .padding(.bottom, Spacing.bottomBarTopOffset)
        .background(Color.black)
    }

    // MARK: - Actions

    private func split() {
        let t = controller.currentTime
        let dur = controller.duration
        guard dur > 0, t > 0.1, t < dur - 0.1 else { return }

        let sorted = video.movesSorted

        if sorted.isEmpty {
            let m1 = Move(name: "", time: 0, endTime: t, video: video)
            let m2 = Move(name: "", time: t, endTime: dur, video: video)
            modelContext.insert(m1)
            modelContext.insert(m2)
        } else {
            guard let segment = sorted.first(where: {
                $0.time <= t && t < ($0.endTime ?? dur)
            }) else { return }
            guard t > segment.time + 0.1 && t < (segment.endTime ?? dur) - 0.1 else { return }

            let after = Move(name: "", time: t, endTime: segment.endTime ?? dur, video: video)
            modelContext.insert(after)
            segment.endTime = t
        }

        // Remember the split point. Both branches above create a move whose
        // start time is `t`, so this is the new move's first frame.
        lastMarkedTime = t

        Haptics.medium()
        refreshSortedMoves()
    }

    private func deleteCurrentVideo() {
        let videoID = video.id
        Task { await ThumbnailService.shared.clearCache(for: videoID) }
        try? FileManager.default.removeItem(at: video.fileURL)
        modelContext.delete(video)
        dismiss()
        Haptics.medium()
    }

    private func finishEditing() {
        controller.pause()
        Haptics.success()
        router.selectedTab = .feed
        // Report the most recently marked move's start time (if any) so a
        // feed presenter can re-open on that move's first frame.
        onFinish?(lastMarkedTime)
        dismiss()
    }

    private func activateMove(_ move: Move) {
        guard let range = playableRange(for: move) else {
            logger.error(
                "Ignoring invalid move range. video=\(video.displayName, privacy: .public), start=\(move.time, privacy: .public), end=\(String(describing: move.endTime), privacy: .public), duration=\(video.duration, privacy: .public)"
            )
            return
        }

        activeMoveID = move.id
        controller.pause()
        controller.playRange(start: range.start, end: range.end)
        Haptics.light()
    }

    private func advanceActiveMove(currentTime t: TimeInterval) {
        guard t.isFinite else { return }
        let dur = effectiveDuration
        guard let m = sortedMoves.first(where: { move in
            guard move.time.isFinite else { return false }
            let start = max(0, min(move.time, dur))
            let end = normalizedEnd(move.endTime, start: start, duration: dur)
            return start <= t && t < end
        }) else { return }
        if m.id != activeMoveID {
            activeMoveID = m.id
            guard let range = playableRange(for: m) else { return }
            controller.setActiveRange(start: range.start, end: range.end)
        }
    }

    private func deleteMove(_ move: Move) {
        let dur = controller.duration

        if sortedMoves.count > 1, let idx = sortedMoves.firstIndex(where: { $0.id == move.id }) {
            if idx > 0 {
                sortedMoves[idx - 1].endTime = move.endTime ?? dur
            } else {
                sortedMoves[idx + 1].time = 0
            }
        }

        if activeMoveID == move.id { activeMoveID = nil }
        modelContext.delete(move)
        refreshSortedMoves(excluding: move.id)
        Haptics.medium()
    }

    private func renameMove(_ move: Move, to name: String) {
        move.name = name
        move.updatedAt = Date()
        Haptics.success()
    }

    private func toggleExclude(_ move: Move) {
        move.isExcluded.toggle()
        move.updatedAt = Date()
        Haptics.light()
    }

    private func refreshSortedMoves(excluding removedID: UUID? = nil) {
        sortedMoves = video.movesSorted.filter { $0.id != removedID }
    }

    private var effectiveDuration: TimeInterval {
        if controller.duration.isFinite, controller.duration > 0 {
            return controller.duration
        }
        return max(0, video.duration)
    }

    private func playableRange(for move: Move) -> (start: TimeInterval, end: TimeInterval?)? {
        let duration = effectiveDuration
        guard duration > 0, move.time.isFinite else { return nil }

        let start = max(0, min(move.time, duration))
        let end = normalizedEnd(move.endTime, start: start, duration: duration)
        guard end > start else { return nil }

        return (start, move.endTime == nil ? nil : end)
    }

    private func normalizedEnd(
        _ endTime: TimeInterval?,
        start: TimeInterval,
        duration: TimeInterval
    ) -> TimeInterval {
        guard let endTime, endTime.isFinite else { return duration }
        return max(start, min(endTime, duration))
    }
}
