import SwiftUI
import SwiftData
import AVKit

enum MovesFilter: String, CaseIterable, Identifiable {
    case named, unnamed, excluded, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .named:    return "Named"
        case .unnamed:  return "Unnamed"
        case .excluded: return "Excluded"
        case .all:      return "All"
        }
    }
}

private struct MoveGroup: Identifiable {
    let id: String
    let title: String
    let moves: [Move]
    let sortDate: Date
}

struct MovesView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var controller = PlaybackController()
    @State private var activeMoveID: UUID?
    @State private var pendingAutoplayMoveID: UUID?
    @State private var activeVideoMoves: [Move] = []
    @State private var filter: MovesFilter = .named
    @State private var moves: [Move] = []
    @State private var isLoading = false
    @State private var canLoadMore = false
    @State private var loadError: String?
    @State private var backfilledVideoIDs: Set<UUID> = []

    private let pageSize = 80

    private var activeMove: Move? {
        guard let id = activeMoveID else { return nil }
        return moves.first { $0.id == id }
    }

    private var moveGroups: [MoveGroup] {
        var groups: [MoveGroup] = []
        var indexesByID: [String: Int] = [:]

        for move in moves {
            let video = move.video
            let groupID = video?.id.uuidString ?? "missing-video"
            let sortDate = video?.recordedAt ?? video?.importedAt ?? .distantPast
            let title = video.map { groupTitle(for: $0) } ?? "Unknown Date"

            if let index = indexesByID[groupID] {
                var groupMoves = groups[index].moves
                groupMoves.append(move)
                groups[index] = MoveGroup(
                    id: groupID,
                    title: groups[index].title,
                    moves: groupMoves.sorted { $0.time < $1.time },
                    sortDate: groups[index].sortDate
                )
            } else {
                indexesByID[groupID] = groups.count
                groups.append(MoveGroup(id: groupID, title: title, moves: [move], sortDate: sortDate))
            }
        }

        return groups.sorted { $0.sortDate > $1.sortDate }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(moveGroups) { group in
                        Section {
                            ForEach(group.moves) { move in
                                MoveRowView(
                                    move: move,
                                    isActive: activeMoveID == move.id,
                                    onTap: { activate(move) },
                                    onCycleStatus: { cycleStatus(move) },
                                    onDelete: { delete(move) },
                                    onRename: { newName in rename(move, to: newName) },
                                    onExclude: { toggleExclude(move) }
                                )
                                .id(move.id)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            }
                        } header: {
                            moveGroupHeader(title: group.title, count: group.moves.count)
                        }
                    }

                    if isLoading && moves.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                    } else if moves.isEmpty {
                        emptyState
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                    }

                    if canLoadMore {
                        Button {
                            Task { await loadMoreMoves() }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Load More")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isLoading)
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(.compact)
                .contentMargins(.top, 0, for: .scrollContent)
                .environment(controller)
                .safeAreaInset(edge: .top, spacing: 0) {
                    topSection
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let m = activeMove {
                        NowPlayingStripView(move: m) {
                            withAnimation { proxy.scrollTo(m.id, anchor: .center) }
                        }
                    }
                }
                .task(id: filter) {
                    await reloadMoves()
                }
                .task(id: moves.count) {
                    await backfillRecordedDates()
                }
                .task(id: pendingAutoplayMoveID) {
                    await playPendingMoveIfNeeded()
                }
            }
            .navigationTitle("Moves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    filterMenu
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                Text("Named").tag(MovesFilter.named)
                Text("Unnamed").tag(MovesFilter.unnamed)
                Text("Excluded").tag(MovesFilter.excluded)
                Text("All").tag(MovesFilter.all)
            }
        } label: {
            Image(systemName: filter == .named
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter: \(filter.label)")
    }

    private func moveGroupHeader(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .textCase(nil)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
    }

    private func groupTitle(for video: Video) -> String {
        (video.recordedAt ?? video.importedAt).formatted(date: .long, time: .omitted)
    }

    // MARK: - Fetching

    @MainActor
    private func reloadMoves() async {
        activeMoveID = nil
        activeVideoMoves = []
        controller.pause()
        moves = []
        canLoadMore = false
        await fetchMoves(offset: 0, replacing: true)
    }

    @MainActor
    private func loadMoreMoves() async {
        await fetchMoves(offset: moves.count, replacing: false)
    }

    @MainActor
    private func fetchMoves(offset: Int, replacing: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        var descriptor = FetchDescriptor<Move>(
            predicate: predicate(for: filter),
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize + 1
        descriptor.fetchOffset = offset

        do {
            var fetched = try modelContext.fetch(descriptor)
            canLoadMore = fetched.count > pageSize
            if canLoadMore {
                fetched.removeLast()
            }
            if replacing {
                moves = fetched
            } else {
                moves.append(contentsOf: fetched)
            }
        } catch {
            loadError = error.localizedDescription
            canLoadMore = false
        }
    }

    @MainActor
    private func backfillRecordedDates() async {
        let videos = videosNeedingRecordedDateBackfill()

        for video in videos {
            backfilledVideoIDs.insert(video.id)
            if let date = await VideoMetadata.recordedDate(at: video.fileURL) {
                video.recordedAt = date
            }
        }
    }

    private func videosNeedingRecordedDateBackfill() -> [Video] {
        var videosByID: [UUID: Video] = [:]

        for move in moves {
            guard let video = move.video,
                  video.recordedAt == nil,
                  !backfilledVideoIDs.contains(video.id)
            else { continue }
            videosByID[video.id] = video
        }

        return Array(videosByID.values)
    }

    private func predicate(for filter: MovesFilter) -> Predicate<Move>? {
        switch filter {
        case .named:
            return #Predicate<Move> { move in
                !move.name.isEmpty && !move.isExcluded
            }
        case .unnamed:
            return #Predicate<Move> { move in
                move.name.isEmpty && !move.isExcluded
            }
        case .excluded:
            return #Predicate<Move> { move in
                move.isExcluded
            }
        case .all:
            return nil
        }
    }

    // MARK: - Top section

    @ViewBuilder
    private var topSection: some View {
        VStack(spacing: 0) {
            if let move = activeMove, let video = move.video {
                playerSection(video: video)
                    .id(video.id)
            } else {
                playerPlaceholder
            }
        }
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func playerSection(video: Video) -> some View {
        VStack(spacing: 0) {
            VideoPlayer(player: controller.player)
                .id(video.id)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.black)

            PlayerControlsBar(controller: controller, onSplit: split)

            TrimTrackView(
                controller: controller,
                videoID: video.id,
                videoURL: video.fileURL,
                moves: activeVideoMoves,
                allowsMarkerEditing: true
            )
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var playerPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray6))
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
            VStack(spacing: 6) {
                Image(systemName: "play.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Tap a move to play")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let title: String = {
            switch filter {
            case .named:    return "No Named Moves"
            case .unnamed:  return "Nothing to Triage"
            case .excluded: return "Nothing Excluded"
            case .all:      return "No Moves Yet"
            }
        }()
        let message: String = {
            switch filter {
            case .named:    return "Name a segment on the Videos tab to see it here."
            case .unnamed:  return "All your segments have names. Nice."
            case .excluded: return "Segments you exclude will appear here."
            case .all:      return "Import a video on the Videos tab to get started."
            }
        }()

        ContentUnavailableView(
            title,
            systemImage: "music.note.list",
            description: Text(message)
        )
    }

    // MARK: - Actions

    private func split() {
        guard let video = activeMove?.video else { return }
        let t = controller.currentTime
        let videoDur = controller.duration
        guard videoDur > 0, t > 0.1, t < videoDur - 0.1 else { return }

        let sorted = video.movesSorted

        if sorted.isEmpty {
            let m1 = Move(name: "", time: 0, endTime: t, video: video)
            let m2 = Move(name: "", time: t, endTime: videoDur, video: video)
            modelContext.insert(m1)
            modelContext.insert(m2)
        } else {
            guard let segment = sorted.first(where: {
                $0.time <= t && t < ($0.endTime ?? videoDur)
            }) else { return }
            guard t > segment.time + 0.1 && t < (segment.endTime ?? videoDur) - 0.1 else { return }

            let after = Move(name: "", time: t, endTime: segment.endTime ?? videoDur, video: video)
            modelContext.insert(after)
            segment.endTime = t
        }

        Haptics.medium()
        activeVideoMoves = video.movesSorted
    }

    private func activate(_ move: Move) {
        guard let video = move.video else { return }
        let videoURL = video.fileURL

        if controller.currentVideoURL != videoURL {
            controller.pause()
            controller = PlaybackController(videoURL: videoURL)
        }

        activeMoveID = move.id
        activeVideoMoves = video.movesSorted
        pendingAutoplayMoveID = move.id
        Haptics.light()
    }

    @MainActor
    private func playPendingMoveIfNeeded() async {
        guard let pendingID = pendingAutoplayMoveID,
              let move = moves.first(where: { $0.id == pendingID }) else { return }

        pendingAutoplayMoveID = nil
        await Task.yield()
        controller.playRange(start: move.time, end: move.endTime)
    }

    private func cycleStatus(_ move: Move) {
        move.status = move.status.next
        move.updatedAt = Date()
        Haptics.select()
    }

    private func rename(_ move: Move, to name: String) {
        move.name = name
        move.updatedAt = Date()
        refreshCurrentPage()
        Haptics.success()
    }

    private func toggleExclude(_ move: Move) {
        move.isExcluded.toggle()
        move.updatedAt = Date()
        refreshCurrentPage()
        Haptics.light()
    }

    private func delete(_ move: Move) {
        guard let video = move.video else {
            if activeMoveID == move.id { activeMoveID = nil }
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

        if activeMoveID == move.id { activeMoveID = nil }
        modelContext.delete(move)
        moves.removeAll { $0.id == move.id }
        Haptics.medium()
    }

    private func refreshCurrentPage() {
        Task { await reloadMoves() }
    }
}
