import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UIKit

struct VideoFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlaybackSession.self) private var session
    @Environment(StyleStore.self) private var styleStore
    @Environment(AppRouter.self) private var router
    // Order shared with the Library pane so the feed's "n / total" position
    // matches the list. importedAt is always present (recordedAt can be nil for
    // Files imports) and keeps a fresh import at index 0 so we can land on it.
    @Query(sort: [
        SortDescriptor(\Video.importedAt, order: .reverse)
    ]) private var allVideos: [Video]

    // Drives the import-time style tag dialog.
    @Query(sort: \Style.createdAt, order: .forward) private var allStyles: [Style]

    @State private var controllers: [UUID: PlaybackController] = [:]
    @State private var activeVideoID: UUID?
    @State private var selectedIndex = 0
    @State private var activeMoveID: UUID?
    @State private var manualMoveSelection: ManualMoveSelection?
    @State private var dragOffset: CGFloat = 0
    @State private var showDetail = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showFilesImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showError = false
    @State private var editorStartTime: TimeInterval?

    // Library pane: a side surface co-equal to the feed. `paneProgress` is the
    // open fraction (0 closed → 1 fully open); the feed parallaxes off to the
    // right as the pane slides in from the left.
    @State private var paneProgress: CGFloat = 0
    // Style picker pane: symmetric to Library but slides in from the right.
    // Mutex with `paneProgress` — opening one snaps the other closed.
    @State private var stylePaneProgress: CGFloat = 0
    @State private var dragAxis: FeedDragAxis?
    // Once a horizontal drag is locked, this records which pane it's driving so
    // we don't flip mid-gesture as the user's finger changes direction.
    @State private var horizontalTarget: HorizontalDragTarget?
    @State private var pendingFeedMove: PendingFeedMove?

    // Import-time style tagging. After videos import we prompt to tag them so
    // the global style mode can scope them.
    @State private var styleTagTargets: [Video] = []
    @State private var showStyleTagPrompt = false

    // Add-video action sheet, presented by the bottom bar's `+` button.
    @State private var showAddVideoDialog = false

    // Videos scoped to the active style mode. The feed and pane share this lens.
    private var videos: [Video] {
        allVideos.filter { styleStore.matches($0) }
    }

    private var isPaneOpen: Bool { paneProgress > 0.5 }
    private var isStylePaneOpen: Bool { stylePaneProgress > 0.5 }

    private var bottomBarActive: BottomBarActive {
        if isPaneOpen { return .library }
        if isStylePaneOpen { return .style }
        return .feed
    }

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

    private var feedRoot: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let video = selectedVideo {
                    feedSurface(for: video)
                } else {
                    emptyState
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    emptyStateTopBar
                        .opacity(coachActive ? 0 : 1)
                        .allowsHitTesting(!coachActive)
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
                    VideoDetailView(
                        video: selectedVideo,
                        startTime: editorStartTime,
                        onFinish: { newMarkedTime in
                            // If the user marked a new move in the editor,
                            // restore the feed on that move's first frame.
                            // Nil → keep the original handoff timestamp.
                            if let t = newMarkedTime {
                                editorStartTime = t
                            }
                        }
                    )
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                feedRoot
                    // Library opens by pushing feed right; Style opens by
                    // pushing feed left. They are mutex so only one term is
                    // ever non-zero.
                    .offset(x: (paneProgress - stylePaneProgress) * geo.size.width)
                    .allowsHitTesting(paneProgress == 0 && stylePaneProgress == 0)

                LibraryPaneView(
                    activeVideoID: activeVideoID,
                    activeMoveID: activeMoveID,
                    onSelectVideo: { openFromPane(video: $0, move: nil) },
                    onSelectMove: { selectMoveFromPane($0) },
                    onImportPhotos: { showPhotosPicker = true },
                    onImportFiles: { showFilesImporter = true },
                    onClose: { settlePane(open: false) }
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .offset(x: (paneProgress - 1) * geo.size.width)
                .allowsHitTesting(paneProgress >= 1)

                StylePickerPaneView(
                    onClose: { settleStylePane(open: false) }
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .offset(x: (1 - stylePaneProgress) * geo.size.width)
                .allowsHitTesting(stylePaneProgress >= 1)

                // Bottom bar is global chrome — it does not ride with the
                // swiping video. The per-video "no moves yet" CTA lives
                // inside the card chrome (see cardChromeStack) so it travels
                // with its video.
                VStack(spacing: Spacing.none) {
                    Spacer(minLength: 0)
                    GlobalBottomBar(
                        active: bottomBarActive,
                        onOpenLibrary: { openLibrary() },
                        onShowFeed: { showFeed() },
                        onAddVideo: { showAddVideoDialog = true },
                        onOpenStyles: { openStyles() }
                    )
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, Spacing.sm)
                }
                .ignoresSafeArea(edges: .bottom)
                .opacity(coachActive || showDetail ? 0 : 1)
                .allowsHitTesting(!coachActive && !showDetail)
                .animation(.easeInOut(duration: 0.25), value: coachActive)
                .animation(.easeInOut(duration: 0.2), value: showDetail)
            }
            .gesture(feedAndPaneGesture(size: geo.size), including: showDetail ? .subviews : .all)
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
        .confirmationDialog(
            styleTagTargets.count > 1 ? "Tag \(styleTagTargets.count) videos" : "What style is this?",
            isPresented: $showStyleTagPrompt,
            titleVisibility: .visible
        ) {
            ForEach(allStyles) { style in
                Button(style.name) { applyStyleToTargets(style) }
            }
            Button("Skip", role: .cancel) { styleTagTargets = [] }
        } message: {
            Text("Tagging keeps videos in the right style mode. You can change it later from the editor.")
        }
        .confirmationDialog(
            "Add video",
            isPresented: $showAddVideoDialog,
            titleVisibility: .visible
        ) {
            Button("From Photos") { showPhotosPicker = true }
            Button("From Files")  { showFilesImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            // Belt-and-braces: ensure the three default Styles exist even on a
            // fresh install (where the V3→V4 migration didn't run because there
            // was no V3 store), then rehydrate the persisted activeStyle.
            Style.seedDefaultsIfNeeded(in: modelContext)
            styleStore.rehydrateIfNeeded(in: modelContext)

            syncWindow(autoplay: true)
            maybeAdvanceCoach()
            if router.selectedTab == .library {
                paneProgress = 1
                activeController?.pause()
            }
        }
        .onChange(of: router.selectedTab) { _, new in
            let shouldBeOpen = (new == .library)
            if isPaneOpen != shouldBeOpen {
                settlePane(open: shouldBeOpen)
            }
        }
        .onChange(of: selectedIndex) { _, _ in syncWindow(autoplay: true) }
        .onChange(of: styleStore.activeStyle) { _, _ in
            // The active lens changed: re-anchor to the top of the new list and
            // rebuild the playback window so we never point at a filtered-out video.
            selectedIndex = 0
            syncWindow(autoplay: !isPaneOpen)
        }
        .onChange(of: videos.count) { _, _ in
            normalizeSelectionAfterDataChange()
            maybeAdvanceCoach()
        }
        .onChange(of: activeController?.currentTime) { _, time in updateActiveMove(for: time ?? 0) }
        .onChange(of: showDetail) { _, presenting in
            // Returning from the editor: resume on the right frame. If the
            // editor reported a newly marked move, `editorStartTime` was
            // overwritten to that move's start; otherwise it's still the
            // handoff-in timestamp. Either way, seek there and play.
            if !presenting {
                ensureFeedSurface()
                if let t = editorStartTime, t.isFinite, t >= 0 {
                    activeController?.seek(to: t)
                }
                editorStartTime = nil
                activeController?.play()
            }
        }
    }

    private func feedSurface(for video: Video) -> some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            videoStack(height: fullHeight, width: geo.size.width, topInset: geo.safeAreaInsets.top)
                .contentShape(Rectangle())
        }
    }

    /// Empty-state CTA card shown above the GlobalBottomBar when the current
    /// source has no marked moves yet. Lives in the outer body's bottom stack
    /// so the bar pushes it up naturally — no manual safe-area math.
    @ViewBuilder
    private var noMovesCTACard: some View {
        VStack(spacing: Spacing.smPlus) {
            Text("No moves yet")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
            Text("You haven't added any moves to this video.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            Button {
                openEditor()
            } label: {
                Label("Add moves", systemImage: "plus.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing.primaryButtonHeight)
                    .background(.white, in: Capsule())
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.12))
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }

    private func shouldShowNoMovesCTA(for video: Video) -> Bool {
        // Suppress while the editor is pushed (it lives inside the feed's
        // NavigationStack, but the CTA lives inside the per-card chrome and
        // would otherwise leak through over the editor).
        guard !showDetail else { return false }
        // Also suppress while a side pane is on screen — the pane is the
        // visible surface; the CTA belongs to the feed view underneath.
        guard !isPaneOpen, !isStylePaneOpen else { return false }
        return video.movesSorted.isEmpty
    }

    private func videoStack(height: CGFloat, width: CGFloat, topInset: CGFloat) -> some View {
        ZStack {
            ForEach(windowIndices, id: \.self) { index in
                let video = videos[index]
                let isActive = index == selectedIndex
                ZStack {
                    if let controller = controllers[video.id] {
                        VideoPlayerSurface(controller: controller, videoGravity: .resizeAspectFill)
                            .overlay(ambientGradient)
                    } else {
                        Color.black
                    }

                    // Tap zones sit between the video and the chrome so chrome
                    // buttons (Loop/Edit, mute) capture their own taps while
                    // background taps still drive prev/play/next.
                    if isActive {
                        tapZones
                            .allowsHitTesting(!coachActive)
                    }

                    // Per-card chrome lives inside the card, so it travels in
                    // and out of view with its video during a swipe — incoming
                    // chrome enters with the incoming card, not after settle.
                    cardChromeStack(for: video, isActive: isActive, fullHeight: height, topInset: topInset)
                        .opacity(coachActive ? 0 : perVideoChromeOpacity)
                        .animation(.easeInOut(duration: 0.25), value: coachActive)
                        .animation(.easeOut(duration: 0.15), value: dragOffset == 0)
                        .allowsHitTesting(isActive && !coachActive)
                }
                .frame(width: width, height: height)
                .offset(y: CGFloat(index - selectedIndex) * height + bandedOffset(height: height))
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }

    // Composite per-card chrome: top rail + title (+ Loop/Edit when active),
    // center playback overlay (active only), and bottom no-moves CTA (per
    // video). Sized to the full card so the top padding lands below the
    // status bar / dynamic island and the bottom padding clears the
    // GlobalBottomBar.
    @ViewBuilder
    private func cardChromeStack(for video: Video, isActive: Bool, fullHeight: CGFloat, topInset: CGFloat) -> some View {
        ZStack {
            VStack(spacing: Spacing.none) {
                topChrome(for: video, isActive: isActive)
                    .padding(.horizontal, Spacing.lgPlus)
                    .padding(.top, topInset + Spacing.smPlus)
                Spacer(minLength: 0)
            }

            if isActive {
                playbackOverlay
            }

            if shouldShowNoMovesCTA(for: video) {
                VStack(spacing: Spacing.none) {
                    Spacer(minLength: 0)
                    noMovesCTACard
                        .padding(.horizontal, Spacing.lgPlus)
                        .padding(.bottom, Spacing.bottomBarTopOffset + Spacing.bottomBarClearance)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                .animation(.snappy(duration: 0.28), value: video.movesSorted.isEmpty)
            }
        }
        .frame(height: fullHeight)
    }

    private func bandedOffset(height: CGFloat) -> CGFloat {
        let atTop = selectedIndex == 0 && dragOffset > 0
        let atBottom = selectedIndex == videos.count - 1 && dragOffset < 0
        guard atTop || atBottom else { return dragOffset }
        let resistance: CGFloat = 0.35
        let maxRubber = height * 0.5
        return max(-maxRubber, min(maxRubber, dragOffset * resistance))
    }

    // Per-video chrome (top rail + title + Loop/Edit, playback overlay, no-moves CTA)
    // rides with the active card's bandedOffset and dips to 0.5 opacity the moment
    // a swipe begins, so it reads as glued to the video it belongs to.
    private var perVideoChromeOpacity: CGFloat {
        dragOffset == 0 ? 1 : 0.5
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
    }

    @ViewBuilder
    private var playbackOverlay: some View {
        if let controller = activeController, !controller.isPlaying, !coachActive {
            GlassCluster(spacing: 14) {
                ZStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .liquidGlass(in: Circle())
                        .allowsHitTesting(false)
                        .offset(y: -(24 + 14 + 13) / 2)

                    Button {
                        session.isMuted.toggle()
                        controller.isMuted = session.isMuted
                        Haptics.light()
                    } label: {
                        Image(systemName: session.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10, weight: .bold))
                            .contentTransition(.identity)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .liquidGlass(in: Circle(), interactive: true)
                    }
                    .accessibilityLabel(session.isMuted ? "Unmute" : "Mute")
                    .offset(y: -3 * (24 + 14 + 13) / 2)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
            .transition(.opacity.combined(with: .scale(scale: 0.86)))
            .environment(\.colorScheme, .dark)
        }
    }

    // Per-card top chrome: rail + title (+ Loop/Edit cluster only on the active
    // card). Neighbor cards render a visual replica with their own video's data
    // so chrome travels with each card during a swipe.
    private func topChrome(for video: Video, isActive: Bool) -> some View {
        let controller = controllers[video.id]
        return VStack(spacing: Spacing.smPlus) {
            FeedSegmentRail(
                moves: video.movesSorted,
                activeMoveID: isActive ? activeMoveID : nil,
                currentTime: controller?.currentTime ?? 0,
                duration: effectiveDuration(for: video),
                onSelect: { move in play(move) }
            )
            .transaction { transaction in
                transaction.animation = nil
            }

            HStack(spacing: Spacing.md) {
                Text(feedTitle(for: video))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transaction { transaction in
                        transaction.animation = nil
                    }

                if isActive {
                    topActionCluster
                }
            }
        }
    }

    @ViewBuilder
    private var topActionCluster: some View {
        if let controller = activeController {
            let noMoves = activeMoves.isEmpty
            GlassCluster(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    LoopRailButton(controller: controller)
                    Button {
                        openEditor()
                    } label: {
                        RailIcon(systemName: noMoves ? "plus" : "pencil")
                    }
                    .accessibilityLabel(noMoves ? "Add moves" : "Edit moves")
                }
            }
        }
    }

    private var emptyStateTopBar: some View {
        EmptyView()
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xl3) {
            Spacer(minLength: Spacing.xl4)

            ZStack {
                Circle()
                    .fill(.cyan.opacity(0.18))
                    .frame(width: 170, height: 170)
                    .blur(radius: Spacing.lgPlus)
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 70, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: Spacing.smPlus) {
                Text("Drop in a dance video")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("567 becomes a full-screen feed: swipe between videos, tap through moves, and swipe right for your library.")
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, Spacing.xl2)
            }

            VStack(spacing: Spacing.md) {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.rowMinHeight)
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
            .padding(.horizontal, Spacing.xl3)

            Spacer(minLength: Spacing.xl)
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

            VStack(spacing: Spacing.lgPlus) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeating)

                Text("Swipe up for your next video")
                    .font(.title3.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl4)

                Button {
                    dismissSwipeCoach()
                } label: {
                    Text("Got it")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, Spacing.xl3)
                        .frame(height: 46)
                        .background(.white, in: Capsule())
                }
                .padding(.top, Spacing.xs)
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

                HStack(spacing: Spacing.none) {
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

                VStack(spacing: Spacing.mdPlus) {
                    Spacer(minLength: 0)

                    Text("Tap the sides to skip between moves")
                        .font(.title3.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl4 + Spacing.xs)
                        .shadow(color: .black.opacity(0.45), radius: 12, y: 4)

                    Button {
                        dismissTapCoach()
                    } label: {
                        Text("Got it")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, Spacing.xl3)
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

            VStack(spacing: Spacing.smPlus) {
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

    // One gesture drives both axes. We lock the axis on the first significant
    // movement: vertical scrubs between videos (feed); horizontal opens/closes
    // a pane. Horizontal target (library vs. style) is chosen on first lock:
    //   - if a pane is already open, that pane is the target (closing it)
    //   - else direction picks: drag right → Library (from left), drag left → Style (from right)
    private func feedAndPaneGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !showDetail else { return }
                if dragAxis == nil {
                    dragAxis = abs(value.translation.width) >= abs(value.translation.height)
                        ? .horizontal : .vertical
                    if dragAxis == .horizontal {
                        horizontalTarget = pickHorizontalTarget(translation: value.translation.width)
                        // Pause the underlying feed the moment a pane swipe begins.
                        if !isPaneOpen, !isStylePaneOpen {
                            activeController?.pause()
                        }
                    }
                }
                switch dragAxis {
                case .horizontal:
                    let delta = value.translation.width / max(size.width, 1)
                    switch horizontalTarget {
                    case .library:
                        let base: CGFloat = isPaneOpen ? 1 : 0
                        paneProgress = min(1, max(0, base + delta))
                    case .style:
                        // Style pane opens with leftward drag (negative delta)
                        // and closes with rightward drag.
                        let base: CGFloat = isStylePaneOpen ? 1 : 0
                        stylePaneProgress = min(1, max(0, base - delta))
                    case .none:
                        break
                    }
                case .vertical:
                    guard !isPaneOpen, !isStylePaneOpen else { return }
                    dragOffset = value.translation.height
                    startNeighborPlayback()
                case .none:
                    break
                }
            }
            .onEnded { value in
                guard !showDetail else {
                    dragAxis = nil
                    horizontalTarget = nil
                    return
                }
                switch dragAxis {
                case .horizontal:
                    let predictedDelta = value.predictedEndTranslation.width / max(size.width, 1)
                    switch horizontalTarget {
                    case .library:
                        let base: CGFloat = isPaneOpen ? 1 : 0
                        settlePane(open: base + predictedDelta > 0.5)
                    case .style:
                        let base: CGFloat = isStylePaneOpen ? 1 : 0
                        settleStylePane(open: base - predictedDelta > 0.5)
                    case .none:
                        break
                    }
                case .vertical:
                    if !isPaneOpen, !isStylePaneOpen {
                        endVerticalSwipe(value: value, height: size.height)
                    }
                case .none:
                    break
                }
                dragAxis = nil
                horizontalTarget = nil
            }
    }

    /// Decide which pane a horizontal drag is acting on. Open panes always
    /// "win" — a drag while a pane is open is interpreted as closing it.
    private func pickHorizontalTarget(translation: CGFloat) -> HorizontalDragTarget {
        if isPaneOpen      { return .library }
        if isStylePaneOpen { return .style }
        return translation >= 0 ? .library : .style
    }

    private func endVerticalSwipe(value: DragGesture.Value, height: CGFloat) {
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

    // MARK: - Panes (Library left, Style right) — mutex

    /// Bottom-bar "Library" button: ensure the left pane is open, the right
    /// pane is closed. Closes the Style pane first if needed.
    private func openLibrary() {
        if isStylePaneOpen { settleStylePane(open: false) }
        settlePane(open: true)
    }

    /// Bottom-bar "Style" button: ensure the right pane is open, the left
    /// pane is closed.
    private func openStyles() {
        if isPaneOpen { settlePane(open: false) }
        settleStylePane(open: true)
    }

    /// Bottom-bar "Feed" button: close any open pane and resume playback.
    private func showFeed() {
        if isPaneOpen      { settlePane(open: false) }
        if isStylePaneOpen { settleStylePane(open: false) }
    }

    private func settlePane(open: Bool) {
        withAnimation(.snappy(duration: 0.34, extraBounce: 0.02)) {
            paneProgress = open ? 1 : 0
        }
        let targetTab: AppTab = open ? .library : .feed
        if router.selectedTab != targetTab {
            router.selectedTab = targetTab
        }
        if open {
            activeController?.pause()
        } else if !isStylePaneOpen {
            resumeFeedAfterPane()
        }
        Haptics.light()
    }

    private func settleStylePane(open: Bool) {
        withAnimation(.snappy(duration: 0.34, extraBounce: 0.02)) {
            stylePaneProgress = open ? 1 : 0
        }
        if open {
            activeController?.pause()
        } else if !isPaneOpen {
            resumeFeedAfterPane()
        }
        Haptics.light()
    }

    private func resumeFeedAfterPane() {
        guard let controller = activeController else { return }
        if let pending = pendingFeedMove, pending.videoID == activeVideoID {
            activeMoveID = pending.moveID
            controller.playRange(start: pending.time, end: pending.endTime)
            pendingFeedMove = nil
        } else {
            controller.play()
        }
    }

    private func selectMoveFromPane(_ move: Move) {
        guard let video = move.video else { return }
        openFromPane(video: video, move: move)
    }

    /// Hands a pane selection back to the feed: parallax the pane closed and
    /// land the feed on the chosen video (and move, if any).
    private func openFromPane(video: Video, move: Move?) {
        guard let idx = videos.firstIndex(where: { $0.id == video.id }) else { return }
        pendingFeedMove = move.map {
            PendingFeedMove(videoID: video.id, moveID: $0.id, time: $0.time, endTime: $0.endTime)
        }
        if idx == selectedIndex {
            withAnimation(.snappy(duration: 0.34, extraBounce: 0.02)) { paneProgress = 0 }
            resumeFeedAfterPane()
        } else {
            withAnimation(.snappy(duration: 0.34, extraBounce: 0.02)) { paneProgress = 0 }
            // Index change drives syncWindow → activate, which applies the
            // pending move once the new video is current.
            selectedIndex = idx
        }
        if router.selectedTab != .feed {
            router.selectedTab = .feed
        }
        Haptics.light()
    }

    private func openEditor() {
        guard selectedVideo != nil else { return }
        ensureFeedSurface()
        // Hand the feed's current playback time to the editor so it opens where
        // the user was looking, and pause the feed's player.
        editorStartTime = activeController?.currentTime
        activeController?.pause()
        showDetail = true
    }

    private func ensureFeedSurface() {
        if paneProgress != 0 {
            paneProgress = 0
        }
        if stylePaneProgress != 0 {
            stylePaneProgress = 0
        }
        if router.selectedTab != .feed {
            router.selectedTab = .feed
        }
    }

    private func applyStyleToTargets(_ style: Style) {
        for video in styleTagTargets { video.style = style }
        styleTagTargets = []
        Haptics.success()
    }

    private func resetCoach() {
        hasSeenFeedSwipeCoach = false
        hasSeenFeedTapCoach = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            maybeAdvanceCoach()
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
        // Honor the app-wide mute preference; switching to a new video must not
        // reset it. `PlaybackSession` is persisted, so this also survives cold
        // launch — a muted user stays muted across sessions.
        controller.isMuted = session.isMuted
        if isNewActive {
            activeMoveID = nil
            if let first = video.movesSorted.first {
                activeMoveID = first.id
                controller.setActiveRange(start: first.time, end: first.endTime)
            } else {
                // No moves: the loop button should loop the whole video, so
                // scope the active range to the full duration.
                controller.setActiveRange(start: 0, end: effectiveDuration(for: video))
            }
        }
        if autoplay { controller.play() }

        // A pane selection targeting this video overrides the default first-move
        // landing: jump to the chosen move and play from there.
        if let pending = pendingFeedMove, pending.videoID == video.id {
            activeMoveID = pending.moveID
            controller.playRange(start: pending.time, end: pending.endTime)
            pendingFeedMove = nil
        }
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
        manualMoveSelection = ManualMoveSelection(move: move)
        withTransaction(Transaction(animation: nil)) {
            activeMoveID = move.id
        }
        activeController?.playRange(start: move.time, end: move.endTime)
        Haptics.select()
    }

    private func updateActiveMove(for time: TimeInterval) {
        guard !activeMoves.isEmpty else { return }
        if let selection = manualMoveSelection {
            if selection.isExpired {
                manualMoveSelection = nil
            } else if !selection.contains(time) {
                return
            }
        }
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

    /// Feed title rules:
    /// - no moves → date the video was recorded (fallback: imported)
    /// - moves exist, active move has a name → that name
    /// - moves exist, active move is unnamed (or none picked yet) → "Unnamed"
    private func feedTitle(for video: Video) -> String {
        if activeMoves.isEmpty {
            let date = video.recordedAt ?? video.importedAt
            return date.formatted(date: .long, time: .omitted)
        }
        let name = activeMove?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Unnamed" : name
    }

    private func effectiveDuration(for video: Video?) -> TimeInterval {
        if let duration = activeController?.duration, duration.isFinite, duration > 0 { return duration }
        return max(0, video?.duration ?? 0)
    }

    private func handlePhotosImport(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer { isImporting = false }

        var firstError: String?
        var imported: [Video] = []
        for item in items {
            let existingSourceIDs = Dictionary(uniqueKeysWithValues: allVideos.compactMap { v in
                v.sourceAssetID.map { ($0, v.id) }
            })
            do {
                let result = try await VideoImporter.import(from: item, existingSourceIDs: existingSourceIDs)
                imported.append(insertVideo(from: result))
            } catch ImportError.alreadyImported {
                continue
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }
        finishImport(imported: imported, firstError: firstError)
    }

    private func handleFilesImport(_ urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        var firstError: String?
        var imported: [Video] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let result = try await VideoImporter.import(fromFileURL: url)
                imported.append(insertVideo(from: result))
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }
        finishImport(imported: imported, firstError: firstError)
    }

    /// Common tail for both import paths: haptics, error surfacing, and the
    /// style-tag prompt for the freshly imported videos.
    private func finishImport(imported: [Video], firstError: String?) {
        if !imported.isEmpty {
            Haptics.success()
            styleTagTargets = imported
            showStyleTagPrompt = true
        }
        if let firstError {
            importError = firstError
            showError = true
        }
    }

    @discardableResult
    private func insertVideo(from result: VideoImportResult) -> Video {
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
        return video
    }
}

private enum FeedDragAxis { case horizontal, vertical }
private enum HorizontalDragTarget { case library, style }

private struct PendingFeedMove {
    let videoID: UUID
    let moveID: UUID
    let time: TimeInterval
    let endTime: TimeInterval?
}

private struct ManualMoveSelection {
    let start: TimeInterval
    let end: TimeInterval?
    let expiresAt: Date

    init(move: Move) {
        start = move.time
        end = move.endTime
        expiresAt = Date().addingTimeInterval(0.35)
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }

    func contains(_ time: TimeInterval) -> Bool {
        guard time.isFinite else { return false }
        let upperBound = end ?? .infinity
        return start <= time && time < max(start, upperBound)
    }
}

private struct FeedSegmentRail: View {
    let moves: [Move]
    let activeMoveID: UUID?
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSelect: (Move) -> Void

    /// Single rail height across all three states (no moves, inactive
    /// segment, active segment) so the bar reads as one consistent shape.
    private static let railHeight: CGFloat = 12

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if moves.isEmpty {
                progressCapsule
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.railHeight)
            } else {
                ForEach(Array(moves.enumerated()), id: \.element.id) { index, move in
                    Button {
                        onSelect(move)
                    } label: {
                        segmentCapsule(for: move, index: index)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.railHeight)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xxs)
        .accessibilityLabel("Move rail")
    }

    private var progressCapsule: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.32))
            FeedProgressFill(fraction: progressFraction)
                .fill(.white)
        }
    }

    private func segmentCapsule(for move: Move, index: Int) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(fill(for: move, index: index))
            if move.id == activeMoveID {
                FeedProgressFill(fraction: segmentProgress(for: move))
                    .fill(.white)
            }
        }
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

    private var progressFraction: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(max(0, min(1, currentTime / duration)))
    }
}

private struct FeedProgressFill: Shape {
    var fraction: CGFloat

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let rawWidth = rect.width * max(0, min(1, fraction))
        let width = rawWidth > 0 ? min(rect.width, max(rect.height, rawWidth)) : 0
        guard width > 0 else { return Path() }

        let fillRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: width,
            height: rect.height
        )
        return Path(roundedRect: fillRect, cornerRadius: rect.height / 2)
    }
}
