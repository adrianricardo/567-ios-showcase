import SwiftUI
import SwiftData
import OSLog

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct VideoDetailView: View {
    let video: Video
    @State private var controller: PlaybackController
    @State private var isCollapsed = false
    @State private var initialSentinelY: CGFloat?
    @State private var activeMoveID: UUID?
    @State private var sortedMoves: [Move] = []
    @Environment(\.modelContext) private var modelContext
    private let logger = Logger(subsystem: "CumbiaMoves", category: "VideoDetail")

    init(video: Video) {
        self.video = video
        self._controller = State(wrappedValue: PlaybackController(videoURL: video.fileURL))
        self._sortedMoves = State(wrappedValue: video.movesSorted)
    }

    private var activeMove: Move? {
        guard let id = activeMoveID else { return nil }
        return sortedMoves.first { $0.id == id }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Color.clear
                    .frame(height: 0)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .global).minY
                            )
                        }
                    )

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

                if sortedMoves.isEmpty {
                    EmptyMovesCoach()
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.plain)
            .environment(controller)
            .onPreferenceChange(ScrollOffsetKey.self) { globalY in
                if initialSentinelY == nil { initialSentinelY = globalY }
                let scrolled = (initialSentinelY ?? globalY) - globalY
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isCollapsed = scrolled > 24
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                PlayerAndTrimSection(
                    video: video,
                    controller: controller,
                    moves: sortedMoves,
                    isCollapsed: $isCollapsed,
                    onSplit: split
                )
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        }
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

// MARK: - Empty-state coach

private struct EmptyMovesCoach: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Split this video into moves")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                CoachStep(number: 1, text: "Play the video above.")
                CoachStep(number: 2, text: "Tap **Split** each time a new move starts.")
                CoachStep(number: 3, text: "Name each segment so you can find it later.")
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CoachStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
        }
    }
}
