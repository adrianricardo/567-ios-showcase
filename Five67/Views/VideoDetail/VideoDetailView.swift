import SwiftUI
import SwiftData
import OSLog

struct VideoDetailView: View {
    let video: Video
    @State private var controller: PlaybackController
    @State private var activeMoveID: UUID?
    @State private var sortedMoves: [Move] = []
    @State private var showRename = false
    @State private var showDeleteConfirm = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    private let logger = Logger(subsystem: "Five67", category: "VideoDetail")

    init(video: Video) {
        self.video = video
        self._controller = State(wrappedValue: PlaybackController(videoURL: video.fileURL))
        self._sortedMoves = State(wrappedValue: video.movesSorted)
    }

    private var activeMove: Move? {
        guard let id = activeMoveID else { return nil }
        return sortedMoves.first { $0.id == id }
    }

    private var hasMoves: Bool { !sortedMoves.isEmpty }

    var body: some View {
        ScrollViewReader { proxy in
            contentList
                .environment(controller)
                .safeAreaInset(edge: .top, spacing: 0) {
                    heroSection
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let m = activeMove {
                        NowPlayingStripView(move: m) {
                            withAnimation { proxy.scrollTo(m.id, anchor: .center) }
                        }
                    }
                }
                .onChange(of: controller.currentTime) { _, t in
                    advanceActiveMove(currentTime: t)
                }
                .onChange(of: video.moves.count) {
                    refreshSortedMoves()
                }
                .onAppear {
                    refreshSortedMoves()
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
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 0) {
            topBar
            VideoHeroView(
                controller: controller,
                video: video,
                moves: sortedMoves,
                allowsMarkerEditing: true,
                showsPlaceholderWhenEmpty: true
            ) {
                VStack(spacing: 14) {
                    MuteRailButton()
                    LoopRailButton(controller: controller)
                    SplitRailButton(controller: controller, onSplit: split)
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")

            Spacer(minLength: 0)

            Text(video.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            if hasMoves {
                Button {
                    finishEditing()
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                }
                .accessibilityLabel("Done editing")
            } else {
                Menu {
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
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color.black)
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            ForEach(sortedMoves) { move in
                MoveRowView(
                    move: move,
                    isActive: activeMoveID == move.id,
                    onTap: { activateMove(move) },
                    onCycleStatus: { cycleStatus(move) },
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
        router.selectedTab = .moves
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

    private func cycleStatus(_ move: Move) {
        move.status = move.status.next
        move.updatedAt = Date()
        Haptics.select()
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
