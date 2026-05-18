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

struct MovesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Move.updatedAt, order: .reverse) private var allMoves: [Move]

    @State private var controller = PlaybackController()
    @State private var activeMoveID: UUID?
    @State private var filter: MovesFilter = .named
    @State private var backfilledVideoIDs: Set<UUID> = []

    private var unnamedCount: Int {
        allMoves.filter { !$0.isExcluded && $0.name.isEmpty }.count
    }

    private var excludedCount: Int {
        allMoves.filter { $0.isExcluded }.count
    }

    private var filteredMoves: [Move] {
        switch filter {
        case .named:
            return allMoves.filter { $0.isNamed }
        case .unnamed:
            return allMoves.filter { !$0.isExcluded && $0.name.isEmpty }
        case .excluded:
            return allMoves.filter { $0.isExcluded }
        case .all:
            return allMoves
        }
    }

    private var groupedMoves: [(video: Video, moves: [Move])] {
        var groups: [UUID: (video: Video, moves: [Move])] = [:]

        for move in filteredMoves {
            guard let video = move.video else { continue }
            if groups[video.id] == nil {
                groups[video.id] = (video, [])
            }
            groups[video.id]?.moves.append(move)
        }

        return groups.values
            .sorted { $0.video.importedAt > $1.video.importedAt }
            .map { group in
                (group.video, group.moves.sorted { $0.time < $1.time })
            }
    }

    private var videosNeedingRecordedDateBackfill: [Video] {
        var videosByID: [UUID: Video] = [:]
        for move in allMoves {
            guard let video = move.video,
                  video.recordedAt == nil,
                  !backfilledVideoIDs.contains(video.id)
            else { continue }
            videosByID[video.id] = video
        }
        return Array(videosByID.values)
    }

    private var activeMove: Move? {
        guard let id = activeMoveID else { return nil }
        return allMoves.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(groupedMoves, id: \.video.id) { group in
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
                            sectionHeader(for: group.video)
                        }
                    }

                    if filteredMoves.isEmpty {
                        emptyState
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(.compact)
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
                .task(id: allMoves.count) {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    await backfillRecordedDates()
                }
                .onChange(of: controller.currentTime) { _, t in
                    advanceActiveMove(currentTime: t)
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
                Text(unnamedCount > 0 ? "Unnamed (\(unnamedCount))" : "Unnamed")
                    .tag(MovesFilter.unnamed)
                Text(excludedCount > 0 ? "Excluded (\(excludedCount))" : "Excluded")
                    .tag(MovesFilter.excluded)
                Text("All").tag(MovesFilter.all)
            }
        } label: {
            Image(systemName: filter == .named
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter: \(filter.label)")
    }

    private func advanceActiveMove(currentTime t: TimeInterval) {
        guard let video = activeMove?.video else { return }
        let sorted = video.movesSorted
        let dur = video.duration
        guard let m = sorted.first(where: { $0.time <= t && t < ($0.endTime ?? dur) }) else { return }
        if m.id != activeMoveID {
            activeMoveID = m.id
            controller.setActiveRange(start: m.time, end: m.endTime)
        }
    }

    @ViewBuilder
    private func sectionHeader(for video: Video) -> some View {
        Text((video.recordedAt ?? video.importedAt).friendlyLabel)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .listRowInsets(EdgeInsets())
    }

    private func backfillRecordedDates() async {
        for video in videosNeedingRecordedDateBackfill {
            backfilledVideoIDs.insert(video.id)
            if let date = await VideoMetadata.recordedDate(at: video.fileURL) {
                await MainActor.run { video.recordedAt = date }
            }
        }
    }

    // MARK: - Top section (filter + player + trim)

    @ViewBuilder
    private var topSection: some View {
        VStack(spacing: 0) {
            if let move = activeMove, let video = move.video {
                playerSection(video: video)
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
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.black)

            PlayerControlsBar(controller: controller)

            TrimTrackView(
                controller: controller,
                videoID: video.id,
                videoURL: video.fileURL,
                moves: video.movesSorted
            )
            .frame(height: 36)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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

    private func activate(_ move: Move) {
        guard let video = move.video else { return }
        controller.loadVideo(url: video.fileURL)
        activeMoveID = move.id
        controller.setActiveRange(start: move.time, end: move.endTime)
        controller.seek(to: move.time)
        controller.play()
        Haptics.light()
    }

    private func cycleStatus(_ move: Move) {
        move.status = move.status.next
        move.updatedAt = Date()
        Haptics.select()
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
        Haptics.medium()
    }
}
