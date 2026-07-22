import SwiftUI
import SwiftData
import OSLog

struct VideoDetailView: View {
    let video: Video
    let startTime: TimeInterval?
    let onFinish: ((TimeInterval?) -> Void)?
    private let finishTitle: String?
    private let secondaryFinishTitle: String?
    private let showsTitle: Bool
    /// Onboarding chrome: when set, the guided-editor progress cue is pinned
    /// above the top bar so it keeps its single position across every beat.
    private let progress: OnboardingProgress?
    /// Distinguishes the secondary exit ("I'll do this later") from the primary
    /// one. Nil keeps the legacy behavior where both call `onFinish`.
    private let onSecondaryFinish: (() -> Void)?
    @State private var controller: PlaybackController
    @State private var activeMoveID: UUID?
    @State private var sortedMoves: [Move] = []
    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var didApplyStartTime = false
    @State private var unlockPrompt: UnlockPromptReason?
    @State private var pendingStyleID: UUID?
    @State private var unlockSucceeded = false
    // Start time of the most recently marked move during this editor session.
    // Reported back to the caller on Done so the feed can re-open on the new
    // move's first frame. Nil means the user didn't mark anything → caller
    // should keep its existing restore behavior.
    @State private var lastMarkedTime: TimeInterval?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(UnlockStore.self) private var unlockStore
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @Query(sort: \Style.createdAt, order: .forward) private var allStyles: [Style]

    private let logger = Logger(subsystem: "Five67", category: "VideoDetail")

    init(
        video: Video,
        startTime: TimeInterval? = nil,
        finishTitle: String? = nil,
        secondaryFinishTitle: String? = nil,
        showsTitle: Bool = true,
        progress: OnboardingProgress? = nil,
        onSecondaryFinish: (() -> Void)? = nil,
        onFinish: ((TimeInterval?) -> Void)? = nil
    ) {
        self.video = video
        self.startTime = startTime
        self.finishTitle = finishTitle
        self.secondaryFinishTitle = secondaryFinishTitle
        self.showsTitle = showsTitle
        self.progress = progress
        self.onSecondaryFinish = onSecondaryFinish
        self.onFinish = onFinish
        self._controller = State(wrappedValue: PlaybackController(videoURL: video.fileURL))
        self._sortedMoves = State(wrappedValue: video.movesSorted)
    }

    private var hasMoves: Bool { !sortedMoves.isEmpty }

    private var styleAccent: Color {
        guard let style = video.style else { return Theme.stagePrimary }
        return StyleAccentPalette.accent(forName: style.name, id: style.id)?.color
            ?? Theme.stagePrimary
    }

    private var stageStroke: Color {
        colorSchemeContrast == .increased ? Theme.stageSecondary.opacity(0.6) : Theme.stageStroke
    }

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
            .overlay(alignment: .leading) {
                Color.clear
                    .frame(width: 20)
                    .contentShape(Rectangle())
                    .highPriorityGesture(editorBackSwipe)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showRename) {
                RenameSheet(
                    title: "Rename Video",
                    isPresented: $showRename,
                    initial: video.displayName
                ) { newName in
                    video.displayName = newName
                }
            }
            .sheet(item: $unlockPrompt, onDismiss: handleUnlockSheetDismiss) { reason in
                UnlockPaywallSheet(reason: reason) {
                    unlockSucceeded = true
                }
            }
            .sheet(isPresented: $showDeleteConfirm) {
                VideoDeleteSheet(video: video) { deleteCurrentVideo() }
            }
            .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: Spacing.none) {
            if let progress {
                OnboardingProgressDots(progress: progress, accent: styleAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.black)
            }
            topBar
            VideoHeroView(
                controller: controller,
                video: video,
                moves: sortedMoves,
                allowsMarkerEditing: true,
                accentColor: styleAccent,
                showsPlaceholderWhenEmpty: true,
                focusesPlaybackOnAppear: true
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
            if let secondaryFinishTitle {
                // The guided editor's escape hatch. It sits opposite the primary
                // action so both exits are visible at once.
                Button(secondaryFinishTitle) { finishEditing(isSecondary: true) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minHeight: Spacing.touchTarget)
            } else if finishTitle == nil {
                Button { finishEditing() } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                }
                .accessibilityLabel("Back")
            } else {
                // Balance the trailing Done button so the title stays centered.
                Color.clear.frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            }

            Spacer(minLength: 0)

            if showsTitle {
                Text(video.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }

            if let finishTitle {
                Button(finishTitle) { finishEditing() }
                    .font(.subheadline.weight(.semibold))
                    .glassNavButtonStyle()
                    .accessibilityLabel(finishTitle)
            } else if showsTitle {
                // Balance the leading back button so the title stays centered.
                Color.clear.frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            }
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
        .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
    }

    /// Picker is bound to the *id* rather than the `Style` itself so SwiftUI
    /// has a stable, `Hashable` tag value (a `Style` reference would need
    /// careful tag identity across re-fetches).
    private var styleBinding: Binding<UUID?> {
        Binding(
            get: { video.style?.id },
            set: { requestStyleChange(to: $0) }
        )
    }

    private func requestStyleChange(to newID: UUID?) {
        guard unlockStore.canUseStyle(newID) else {
            pendingStyleID = newID
            unlockPrompt = .styleLimit
            return
        }
        unlockStore.recordStyleUse(newID)
        video.style = newID.flatMap { id in allStyles.first(where: { $0.id == id }) }
    }

    private func applyPendingStyle() {
        let styleID = pendingStyleID
        pendingStyleID = nil
        requestStyleChange(to: styleID)
    }

    private func handleUnlockSheetDismiss() {
        guard unlockSucceeded else { return }
        unlockSucceeded = false
        applyPendingStyle()
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
                        onExclude: { toggleExclude(move) },
                        accentColor: styleAccent,
                        activeForegroundColor: Theme.stagePrimary
                    )
                    .id(move.id)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(stageStroke, lineWidth: 1)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: Spacing.xs,
                            leading: Spacing.lg,
                            bottom: Spacing.xs,
                            trailing: Spacing.lg
                        )
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(Spacing.sm)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(Theme.stageBackground)
        } else {
            emptyMovesHint
        }
    }

    private var editorBackSwipe: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let predictedDistance = value.predictedEndTranslation.width
                let verticalDistance = abs(value.translation.height)
                let startedAtLeadingEdge = value.startLocation.x <= 36
                let isRightSwipe = horizontalDistance > 70 || predictedDistance > 130
                let isMostlyHorizontal = horizontalDistance > verticalDistance * 1.4

                guard startedAtLeadingEdge, isRightSwipe, isMostlyHorizontal else { return }
                finishEditing()
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
            .foregroundStyle(Theme.stageSecondary)
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
        .foregroundStyle(Theme.stageSecondary)
        .background(Theme.stageBackground)
    }

    // MARK: - Actions

    private func split() {
        let t = controller.currentTime
        let dur = effectiveDuration
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
        VideoDeletionService.delete(video, in: modelContext, unlockStore: unlockStore)
        dismiss()
    }

    private func finishEditing(isSecondary: Bool = false) {
        controller.pause()
        if lastMarkedTime == nil {
            Haptics.light()
        } else {
            Haptics.success()
        }
        router.selectedTab = .feed
        if isSecondary, let onSecondaryFinish {
            onSecondaryFinish()
        } else {
            // Report the most recently marked move's start time (if any) so a
            // feed presenter can re-open on that move's first frame.
            onFinish?(lastMarkedTime)
        }
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
