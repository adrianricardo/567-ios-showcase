import SwiftUI
import SwiftData

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct VideoDetailView: View {
    let video: Video
    @State private var controller: PlaybackController
    @State private var isCollapsed = false
    @State private var initialSentinelY: CGFloat?
    @State private var activeMoveID: UUID?
    @Environment(\.modelContext) private var modelContext

    init(video: Video) {
        self.video = video
        self._controller = State(wrappedValue: PlaybackController(videoURL: video.fileURL))
    }

    private var activeMove: Move? {
        guard let id = activeMoveID else { return nil }
        return video.movesSorted.first { $0.id == id }
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

                ForEach(video.movesSorted) { move in
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

                if video.movesSorted.isEmpty {
                    ContentUnavailableView(
                        "No Segments Yet",
                        systemImage: "scissors",
                        description: Text("Scrub to a moment and tap Split to divide the video.")
                    )
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
    }

    private func activateMove(_ move: Move) {
        activeMoveID = move.id
        controller.setActiveRange(start: move.time, end: move.endTime)
        controller.seek(to: move.time)
        controller.play()
        Haptics.light()
    }

    private func advanceActiveMove(currentTime t: TimeInterval) {
        let sorted = video.movesSorted
        let dur = video.duration
        guard let m = sorted.first(where: { $0.time <= t && t < ($0.endTime ?? dur) }) else { return }
        if m.id != activeMoveID {
            activeMoveID = m.id
            controller.setActiveRange(start: m.time, end: m.endTime)
        }
    }

    private func cycleStatus(_ move: Move) {
        move.status = move.status.next
        move.updatedAt = Date()
        Haptics.select()
    }

    private func deleteMove(_ move: Move) {
        let sorted = video.movesSorted
        let dur = controller.duration

        if sorted.count > 1, let idx = sorted.firstIndex(where: { $0.id == move.id }) {
            if idx > 0 {
                sorted[idx - 1].endTime = move.endTime ?? dur
            } else {
                sorted[idx + 1].time = 0
            }
        }

        if activeMoveID == move.id { activeMoveID = nil }
        modelContext.delete(move)
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
}
