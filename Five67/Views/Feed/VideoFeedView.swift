import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UIKit

struct VideoFeedView: View {
    @Environment(\.modelContext) private var modelContext
    // Order shared with LibraryView so the feed's "n / total" position matches
    // the library list. importedAt is always present (recordedAt can be nil for
    // Files imports) and keeps a fresh import at index 0 so we can land on it.
    @Query(sort: [
        SortDescriptor(\Video.importedAt, order: .reverse)
    ]) private var videos: [Video]

    @State private var controllers: [UUID: PlaybackController] = [:]
    @State private var activeVideoID: UUID?
    @State private var selectedIndex = 0
    @State private var activeMoveID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var showActionTray = false
    @State private var showLibrary = false
    @State private var showDetail = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showFilesImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showError = false
    @State private var editorStartTime: TimeInterval?

    // Two-beat coach. Beat 1 teaches the non-obvious axis (swipe = different
    // video). Beat 2 teaches the move tap-zones (left/right thirds of the
    // screen). Each beat persists independently and fires at most once; Beat 2
    // is gated on Beat 1 already being done so they never overlap.
    @AppStorage("hasSeenFeedSwipeCoach") private var hasSeenFeedSwipeCoach = false
    @AppStorage("hasSeenFeedTapCoach") private var hasSeenFeedTapCoach = false
    @State private var showSwipeCoach = false
    @State private var showTapCoach = false

    private var selectedVideo: Video? {
        guard videos.indices.contains(selectedIndex) else { return nil }
        return videos[selectedIndex]
    }

    private var activeController: PlaybackController? {
        guard let activeVideoID else { return nil }
        return controllers[activeVideoID]
    }

    private var windowIndices: [Int] {
        guard !videos.isEmpty else { return [] }
        let lo = max(0, selectedIndex - 1)
        let hi = min(videos.count - 1, selectedIndex + 1)
        return Array(lo...hi)
    }

    private var activeMoves: [Move] {
        selectedVideo?.movesSorted ?? []
    }

    private var activeMove: Move? {
        guard let activeMoveID else { return nil }
        return activeMoves.first { $0.id == activeMoveID }
    }

    /// True while either coach beat is on screen. We hide every non-video
    /// chrome element behind this so the lesson is the only thing competing
    /// for attention.
    private var coachActive: Bool { showSwipeCoach || showTapCoach }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let video = selectedVideo {
                    feedSurface(for: video)
                } else {
                    emptyState
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if showSwipeCoach {
                    swipeCoachOverlay
                        .transition(.opacity)
                } else if showTapCoach {
                    tapCoachOverlay
                        .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .navigationDestination(isPresented: $showDetail) {
                if let selectedVideo {
                    VideoDetailView(video: selectedVideo, startTime: editorStartTime)
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $pickerItems,
            maxSelectionCount: 0,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            let batch = items
            pickerItems = []
            Task { await handlePhotosImport(batch) }
        }
        .fileImporter(
            isPresented: $showFilesImporter,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await handleFilesImport(urls) }
            case .failure(let err):
                if (err as NSError).code != NSUserCancelledError {
                    importError = err.localizedDescription
                    showError = true
                }
            }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showActionTray) {
            FeedActionTray(
                video: selectedVideo,
                activeMove: activeMove,
                moveCount: activeMoves.count,
                onOpenEditor: {
                    showActionTray = false
                    guard selectedVideo != nil else { return }
                    // Hand the feed's current playback time to the editor so it
                    // opens where the user was looking, and pause the feed's
                    // player so the two surfaces don't play over each other.
                    editorStartTime = activeController?.currentTime
                    activeController?.pause()
                    showDetail = true
                },
                onImportPhotos: {
                    showActionTray = false
                    showPhotosPicker = true
                },
                onImportFiles: {
                    showActionTray = false
                    showFilesImporter = true
                },
                onResetCoach: {
                    showActionTray = false
                    // Flip the flags directly from the app, then re-trigger.
                    // Bypasses cfprefsd because the app writes its own defaults.
                    hasSeenFeedSwipeCoach = false
                    hasSeenFeedTapCoach = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        maybeAdvanceCoach()
                    }
                }
            )
            .presentationDetents([.height(330), .medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            syncWindow(autoplay: true)
            maybeAdvanceCoach()
        }
        .onChange(of: selectedIndex) { _, _ in syncWindow(autoplay: true) }
        .onChange(of: videos.count) { _, _ in
            normalizeSelectionAfterDataChange()
            maybeAdvanceCoach()
        }
        .onChange(of: activeController?.currentTime) { _, time in updateActiveMove(for: time ?? 0) }
        .onChange(of: showDetail) { _, presenting in
            // Returning from the editor: resume the feed where it left off.
            if !presenting {
                editorStartTime = nil
                activeController?.play()
            }
        }
    }

    private func feedSurface(for video: Video) -> some View {
        GeometryReader { geo in
            ZStack {
                videoStack(height: geo.size.height, width: geo.size.width)

                tapZones

                playbackOverlay

                VStack(spacing: 0) {
                    topChrome(video: video)
                    Spacer(minLength: 0)
                    bottomChrome(video: video)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, max(18, geo.safeAreaInsets.bottom + 8))
                .opacity(coachActive ? 0 : chromeOpacity(height: geo.size.height))
                .animation(.easeInOut(duration: 0.25), value: coachActive)
                .allowsHitTesting(!coachActive)

                VStack {
                    Spacer(minLength: 0)
                    VideoPeekIndicator(
                        currentIndex: selectedIndex,
                        totalCount: videos.count,
                        dragOffset: dragOffset
                    )
                    .padding(.bottom, max(110, geo.safeAreaInsets.bottom + 92))
                }
                .allowsHitTesting(false)
                .opacity(coachActive ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: coachActive)
            }
            .contentShape(Rectangle())
            .gesture(verticalSwipeGesture(height: geo.size.height))
        }
    }

    private func videoStack(height: CGFloat, width: CGFloat) -> some View {
        ZStack {
            ForEach(windowIndices, id: \.self) { index in
                let video = videos[index]
                Group {
                    if let controller = controllers[video.id] {
                        VideoPlayerSurface(controller: controller)
                            .overlay(ambientGradient)
                    } else {
                        Color.black
                    }
                }
                .frame(width: width, height: height)
                .offset(y: CGFloat(index - selectedIndex) * height + bandedOffset(height: height))
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }

    private func bandedOffset(height: CGFloat) -> CGFloat {
        let atTop = selectedIndex == 0 && dragOffset > 0
        let atBottom = selectedIndex == videos.count - 1 && dragOffset < 0
        guard atTop || atBottom else { return dragOffset }
        let resistance: CGFloat = 0.35
        let maxRubber = height * 0.5
        return max(-maxRubber, min(maxRubber, dragOffset * resistance))
    }

    private func chromeOpacity(height: CGFloat) -> CGFloat {
        let progress = min(abs(dragOffset) / max(height * 0.5, 1), 1)
        return 1 - progress * 0.85
    }

    private var ambientGradient: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.62),
                .black.opacity(0.05),
                .black.opacity(0.12),
                .black.opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    jumpToPreviousMove()
                    dismissTapCoach()
                }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { togglePlayback() }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    jumpToNextMove()
                    dismissTapCoach()
                }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.22).onEnded { _ in
                activeController?.pause()
                Haptics.light()
                withAnimation(.snappy(duration: 0.32, extraBounce: 0.02)) {
                    showActionTray = true
                }
            }
        )
    }

    @ViewBuilder
    private var playbackOverlay: some View {
        if let controller = activeController, !controller.isPlaying, !coachActive {
            ZStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.45), in: Circle())
                    .allowsHitTesting(false)

                Button {
                    controller.isMuted.toggle()
                    Haptics.light()
                } label: {
                    Image(systemName: controller.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .bold))
                        .contentTransition(.identity)
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel(controller.isMuted ? "Unmute" : "Mute")
                .offset(y: -(24 + 14 + 13))
            }
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
            .transition(.opacity.combined(with: .scale(scale: 0.86)))
        }
    }

    private func topChrome(video: Video) -> some View {
        VStack(spacing: 14) {
            FeedSegmentRail(
                moves: activeMoves,
                activeMoveID: activeMoveID,
                currentTime: activeController?.currentTime ?? 0,
                duration: effectiveDuration(for: video),
                onSelect: { move in play(move) }
            )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(video.displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                }

                Spacer(minLength: 0)

                Button {
                    Haptics.light()
                    showLibrary = true
                } label: {
                    Label("Library", systemImage: "square.grid.2x2.fill")
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16)))
                }
                .accessibilityLabel("Open library")
            }
        }
    }

    private func bottomChrome(video: Video) -> some View {
        VStack(spacing: 16) {
            if let activeMove {
                MoveCard(move: activeMove, index: activeMoveIndex, total: activeMoves.count)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                DiscoveryHintCard(duration: effectiveDuration(for: video), moveCount: activeMoves.count)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Prev/Next removed: the segment rail and edge taps already move
            // between moves. The bottom row carries only the unique action.
            Button {
                Haptics.medium()
                showActionTray = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("Open actions")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: [Color.white, Color(red: 0.76, green: 0.92, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .shadow(color: .cyan.opacity(0.28), radius: 20, y: 8)
            }
        }
        .animation(.snappy(duration: 0.28, extraBounce: 0.03), value: activeMoveID)
    }

    private var emptyState: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 30)

            ZStack {
                Circle()
                    .fill(.cyan.opacity(0.18))
                    .frame(width: 170, height: 170)
                    .blur(radius: 18)
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 70, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 10) {
                Text("Drop in a dance video")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("Five67 becomes a full-screen feed: swipe between videos, tap through moves, then open the tray when you want to edit.")
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white, in: Capsule())
                }
                Button {
                    showFilesImporter = true
                } label: {
                    Label("Import from Files", systemImage: "folder")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.14)))
                }
            }
            .padding(.horizontal, 26)

            Spacer(minLength: 20)
        }
        .background(
            RadialGradient(colors: [.cyan.opacity(0.24), .purple.opacity(0.13), .black], center: .top, startRadius: 20, endRadius: 620)
                .ignoresSafeArea()
        )
    }

    // MARK: - Coach beats

    // Beat 1 — teaches the non-obvious axis: vertical swipe = different video.
    // Scrim is non-hit-testing so the user's first swipe passes through and
    // self-dismisses the overlay by doing the thing it teaches.
    private var swipeCoachOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeating)

                Text("Swipe up for your next video")
                    .font(.title3.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)

                Button {
                    dismissSwipeCoach()
                } label: {
                    Text("Got it")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .frame(height: 46)
                        .background(.white, in: Capsule())
                }
                .padding(.top, 4)
            }
        }
    }

    // Beat 2 — highlights the left/right tap-zones for moving between moves.
    // Scrim is non-hit-testing so a side tap reaches the underlying tap zone
    // and self-dismisses by doing the thing it teaches.
    private var tapCoachOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    tapZoneHighlight(
                        label: "Previous move",
                        systemImage: "chevron.left"
                    )
                    Color.clear
                    tapZoneHighlight(
                        label: "Next move",
                        systemImage: "chevron.right"
                    )
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    Spacer(minLength: 0)

                    Text("Tap the sides to skip between moves")
                        .font(.title3.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .shadow(color: .black.opacity(0.45), radius: 12, y: 4)

                    Button {
                        dismissTapCoach()
                    } label: {
                        Text("Got it")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 28)
                            .frame(height: 46)
                            .background(.white, in: Capsule())
                    }
                    .padding(.bottom, max(140, geo.safeAreaInsets.bottom + 120))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func tapZoneHighlight(label: String, systemImage: String) -> some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.10))
                .overlay(Rectangle().stroke(.white.opacity(0.35), lineWidth: 1))

            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
                Text(label)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Picks the next coach beat to show given what's already been seen and
    /// whether there's any content to demonstrate on. Called from `.onAppear`
    /// and whenever the video count changes (e.g. first import).
    private func maybeAdvanceCoach() {
        guard !videos.isEmpty else { return }
        guard !showSwipeCoach, !showTapCoach else { return }

        if !hasSeenFeedSwipeCoach {
            withAnimation(.easeInOut(duration: 0.3)) { showSwipeCoach = true }
        } else if !hasSeenFeedTapCoach {
            withAnimation(.easeInOut(duration: 0.3)) { showTapCoach = true }
        }
    }

    private func dismissSwipeCoach() {
        guard showSwipeCoach else { return }
        hasSeenFeedSwipeCoach = true
        withAnimation(.easeInOut(duration: 0.25)) { showSwipeCoach = false }
        // Hand off to Beat 2 on the next runloop so the transitions don't
        // collide and so the user sees a beat, not a cross-fade.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            maybeAdvanceCoach()
        }
    }

    private func dismissTapCoach() {
        guard showTapCoach else { return }
        hasSeenFeedTapCoach = true
        withAnimation(.easeInOut(duration: 0.25)) { showTapCoach = false }
    }

    private func verticalSwipeGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = value.translation.height
                startNeighborPlayback()
            }
            .onEnded { value in
                let threshold = min(170, height * 0.18)
                let projected = value.predictedEndTranslation.height
                if projected < -threshold {
                    moveToNextSource()
                } else if projected > threshold {
                    moveToPreviousSource()
                } else {
                    pauseNeighbors()
                    withAnimation(.snappy(duration: 0.28, extraBounce: 0.05)) { dragOffset = 0 }
                }
            }
    }

    private func moveToNextSource() {
        guard selectedIndex < videos.count - 1 else {
            reboundDrag()
            return
        }
        withAnimation(.snappy(duration: 0.34, extraBounce: 0.04)) {
            selectedIndex += 1
            dragOffset = 0
        }
        Haptics.medium()
        dismissSwipeCoach()
    }

    private func moveToPreviousSource() {
        guard selectedIndex > 0 else {
            reboundDrag()
            return
        }
        withAnimation(.snappy(duration: 0.34, extraBounce: 0.04)) {
            selectedIndex -= 1
            dragOffset = 0
        }
        Haptics.medium()
        dismissSwipeCoach()
    }

    private func reboundDrag() {
        Haptics.light()
        withAnimation(.bouncy(duration: 0.42, extraBounce: 0.18)) { dragOffset = 0 }
    }

    private func syncWindow(autoplay: Bool) {
        guard !videos.isEmpty else {
            teardownControllers(keeping: [])
            activeVideoID = nil
            activeMoveID = nil
            return
        }
        var keep = Set<UUID>()
        for index in windowIndices {
            let video = videos[index]
            keep.insert(video.id)
            let controller = ensureController(for: video)
            if index == selectedIndex {
                activate(controller, video: video, autoplay: autoplay)
            } else {
                controller.isMuted = true
                controller.pause()
            }
        }
        teardownControllers(keeping: keep)
    }

    private func startNeighborPlayback() {
        for index in windowIndices where index != selectedIndex {
            guard let controller = controllers[videos[index].id], !controller.isPlaying else { continue }
            controller.isMuted = true
            controller.play()
        }
    }

    private func pauseNeighbors() {
        for index in windowIndices where index != selectedIndex {
            controllers[videos[index].id]?.pause()
        }
    }

    private func ensureController(for video: Video) -> PlaybackController {
        if let existing = controllers[video.id] { return existing }
        let controller = PlaybackController()
        controller.isMuted = true
        controller.loadVideo(url: video.fileURL)
        controllers[video.id] = controller
        return controller
    }

    private func activate(_ controller: PlaybackController, video: Video, autoplay: Bool) {
        let isNewActive = activeVideoID != video.id
        activeVideoID = video.id
        controller.isMuted = false
        if isNewActive {
            activeMoveID = nil
            if let first = video.movesSorted.first {
                activeMoveID = first.id
                controller.setActiveRange(start: first.time, end: first.endTime)
            }
        }
        if autoplay { controller.play() }
    }

    private func teardownControllers(keeping keep: Set<UUID>) {
        for (id, controller) in controllers where !keep.contains(id) {
            controller.pause()
            controllers[id] = nil
        }
    }

    private func normalizeSelectionAfterDataChange() {
        guard !videos.isEmpty else {
            teardownControllers(keeping: [])
            selectedIndex = 0
            activeVideoID = nil
            activeMoveID = nil
            return
        }
        if selectedIndex >= videos.count { selectedIndex = max(0, videos.count - 1) }
        syncWindow(autoplay: true)
    }

    private func togglePlayback() {
        withAnimation(.snappy(duration: 0.2)) {
            activeController?.toggle()
        }
        Haptics.light()
    }

    private func jumpToNextMove() {
        guard let controller = activeController else { return }
        guard !activeMoves.isEmpty else {
            controller.seek(to: min(controller.currentTime + 2, effectiveDuration(for: selectedVideo)))
            Haptics.light()
            return
        }
        let nextIndex = min(activeMoveIndex + 1, activeMoves.count - 1)
        play(activeMoves[nextIndex])
    }

    private func jumpToPreviousMove() {
        guard let controller = activeController else { return }
        guard !activeMoves.isEmpty else {
            controller.seek(to: max(controller.currentTime - 2, 0))
            Haptics.light()
            return
        }
        let previousIndex = max(activeMoveIndex - 1, 0)
        play(activeMoves[previousIndex])
    }

    private var activeMoveIndex: Int {
        guard let activeMoveID,
              let index = activeMoves.firstIndex(where: { $0.id == activeMoveID }) else { return 0 }
        return index
    }

    private func play(_ move: Move) {
        activeMoveID = move.id
        activeController?.playRange(start: move.time, end: move.endTime)
        Haptics.select()
    }

    private func updateActiveMove(for time: TimeInterval) {
        guard !activeMoves.isEmpty else { return }
        let duration = effectiveDuration(for: selectedVideo)
        guard let current = activeMoves.first(where: { move in
            let end = move.endTime ?? duration
            return move.time <= time && time < max(move.time, end)
        }) else { return }
        if current.id != activeMoveID {
            activeMoveID = current.id
            activeController?.setActiveRange(start: current.time, end: current.endTime)
        }
    }

    private func effectiveDuration(for video: Video?) -> TimeInterval {
        if let duration = activeController?.duration, duration.isFinite, duration > 0 { return duration }
        return max(0, video?.duration ?? 0)
    }

    private func handlePhotosImport(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer { isImporting = false }

        var firstError: String?
        var successCount = 0
        for item in items {
            let existingSourceIDs = Dictionary(uniqueKeysWithValues: videos.compactMap { v in
                v.sourceAssetID.map { ($0, v.id) }
            })
            do {
                let result = try await VideoImporter.import(from: item, existingSourceIDs: existingSourceIDs)
                insertVideo(from: result)
                successCount += 1
            } catch ImportError.alreadyImported {
                continue
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }
        if successCount > 0 { Haptics.success() }
        if let firstError {
            importError = firstError
            showError = true
        }
    }

    private func handleFilesImport(_ urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        var firstError: String?
        var successCount = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let result = try await VideoImporter.import(fromFileURL: url)
                insertVideo(from: result)
                successCount += 1
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }
        if successCount > 0 { Haptics.success() }
        if let firstError {
            importError = firstError
            showError = true
        }
    }

    private func insertVideo(from result: VideoImportResult) {
        let video = Video(
            displayName: result.displayName,
            localFilename: result.filename,
            sourceAssetID: result.sourceID,
            recordedAt: result.recordedAt,
            duration: result.duration
        )
        modelContext.insert(video)
        selectedIndex = 0

        let videoURL = video.fileURL
        let videoID = video.id
        let duration = video.duration
        Task.detached(priority: .utility) {
            _ = await ThumbnailService.shared.thumbnails(
                for: videoURL,
                videoID: videoID,
                count: 10,
                height: 36,
                duration: duration
            )
        }
    }
}

private struct FeedSegmentRail: View {
    let moves: [Move]
    let activeMoveID: UUID?
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSelect: (Move) -> Void

    var body: some View {
        HStack(spacing: 5) {
            if moves.isEmpty {
                Capsule()
                    .fill(.white.opacity(0.32))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: progressWidth(totalWidth: 200))
                    }
            } else {
                ForEach(Array(moves.enumerated()), id: \.element.id) { index, move in
                    Button {
                        onSelect(move)
                    } label: {
                        Capsule()
                            .fill(fill(for: move, index: index))
                            .frame(height: move.id == activeMoveID ? 9 : 5)
                            .overlay(alignment: .leading) {
                                if move.id == activeMoveID {
                                    Capsule()
                                        .fill(.white)
                                        .frame(maxWidth: .infinity)
                                        .scaleEffect(x: segmentProgress(for: move), y: 1, anchor: .leading)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: move.id == activeMoveID ? 68 : 34)
                    .animation(.snappy(duration: 0.26, extraBounce: 0.06), value: activeMoveID)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 14)
        .padding(.horizontal, 2)
        .accessibilityLabel("Move rail")
    }

    private func fill(for move: Move, index: Int) -> Color {
        if move.id == activeMoveID { return .white.opacity(0.35) }
        if index < activeIndex { return .white.opacity(0.7) }
        return .white.opacity(0.25)
    }

    private var activeIndex: Int {
        guard let activeMoveID,
              let index = moves.firstIndex(where: { $0.id == activeMoveID }) else { return 0 }
        return index
    }

    private func segmentProgress(for move: Move) -> CGFloat {
        let end = move.endTime ?? duration
        let span = max(0.1, end - move.time)
        return CGFloat(max(0, min(1, (currentTime - move.time) / span)))
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return totalWidth * CGFloat(max(0, min(1, currentTime / duration)))
    }
}

private struct MoveCard: View {
    let move: Move
    let index: Int
    let total: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Move \(index + 1) of \(max(total, 1))")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.cyan.opacity(0.9))
                Text(move.name.isEmpty ? "Untitled move" : move.name)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(move.rangeLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
            }
            Spacer(minLength: 0)
            Image(systemName: move.isExcluded ? "eye.slash.fill" : "sparkle.magnifyingglass")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.13), in: Circle())
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.16)))
    }
}

private struct DiscoveryHintCard: View {
    let duration: TimeInterval
    let moveCount: Int

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "hand.tap.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(moveCount == 0 ? "Tap right to skim" : "Tap through moves")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Swipe vertically between videos · long-press for actions · \(formatTime(duration))")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.14)))
    }
}

private struct VideoPeekIndicator: View {
    let currentIndex: Int
    let totalCount: Int
    let dragOffset: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: dragOffset < 0 ? "arrow.down" : "arrow.up")
                .font(.caption.weight(.bold))
            Text("\(currentIndex + 1) / \(max(totalCount, 1))")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white.opacity(abs(dragOffset) > 20 ? 0.88 : 0.52))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.34), in: Capsule())
        .scaleEffect(abs(dragOffset) > 60 ? 1.06 : 1)
        .animation(.snappy(duration: 0.22, extraBounce: 0.04), value: dragOffset)
    }
}

private struct FeedPillButton: View {
    let title: String
    let systemName: String
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: compact ? 50 : 120, height: 50)
                .background(.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.14)))
        }
        .accessibilityLabel(title)
    }
}

private struct FeedActionTray: View {
    let video: Video?
    let activeMove: Move?
    let moveCount: Int
    let onOpenEditor: () -> Void
    let onImportPhotos: () -> Void
    let onImportFiles: () -> Void
    let onResetCoach: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activeMove?.name.isEmpty == false ? activeMove!.name : video?.displayName ?? "Five67")
                        .font(.title2.weight(.heavy))
                        .lineLimit(2)
                    Text("\(moveCount) moves in this video. Keep browsing like a feed, or jump into the editor when something feels worth keeping.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    TrayActionButton(title: "Edit moves", subtitle: "Timeline + labels", systemName: "slider.horizontal.3", action: onOpenEditor)
                    TrayActionButton(title: "Photos", subtitle: "Import videos", systemName: "photo.on.rectangle", action: onImportPhotos)
                    TrayActionButton(title: "Files", subtitle: "Drop footage", systemName: "folder", action: onImportFiles)
                    #if DEBUG
                    TrayActionButton(title: "Reset coach", subtitle: "Debug · replay beats", systemName: "arrow.counterclockwise", action: onResetCoach)
                    #endif
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Actions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TrayActionButton: View {
    let title: String
    let subtitle: String
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
