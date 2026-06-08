import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UIKit

struct VideoFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(PlaybackSession.self) private var session
    @Environment(StyleStore.self) private var styleStore
    @Environment(AppRouter.self) private var router
    // Order shared with the Library tab so the feed's "n / total" position
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

    // Pending feed move landing from router (replacing the old pane → feed handoff).
    @State private var pendingFeedMove: PendingFeedMove?

    // Import-time style tagging. After videos import we prompt to tag them so
    // the global style mode can scope them.
    @State private var styleTagTargets: [Video] = []
    @State private var showStyleTagPrompt = false

    // Add-video action sheet, presented by the Add button or Library import actions.
    @State private var showAddVideoDialog = false

    // Axis lock for the feed drag gesture — once a drag commits to an axis it
    // stays there. Vertical pages between videos; horizontal scrubs the playhead.
    @State private var isVerticalDrag: Bool?

    // Horizontal scrub state. While a finger is dragging horizontally we seek the
    // whole clip across move boundaries; the active-move loop clamp is lifted for
    // the duration and re-armed on release.
    @State private var isScrubbing = false
    @State private var scrubStartTime: TimeInterval = 0
    @State private var scrubWasPlaying = false
    @State private var scrubLastMoveID: UUID?

    /// How a horizontal drag maps to playback time. Flip this constant and
    /// rebuild to compare the two feels on device.
    /// - `relative`: anchored at the playhead, drag *delta* scaled by `scrubSpan`.
    /// - `absolute`: finger X position maps straight to the timeline (left = 0,
    ///   right = end); the playhead jumps to the finger on touch.
    private enum ScrubMapping { case relative, absolute }
    private static let scrubMapping: ScrubMapping = .absolute

    // Two-beat coach. Beat 1 teaches the non-obvious axis (swipe = different
    // video). Beat 2 teaches the move tap-zones (left/right thirds of the
    // screen). Each beat persists independently and fires at most once; Beat 2
    // is gated on Beat 1 already being done so they never overlap.
    @AppStorage("hasSeenFeedSwipeCoach") private var hasSeenFeedSwipeCoach = false
    @AppStorage("hasSeenFeedTapCoach") private var hasSeenFeedTapCoach = false
    @State private var showSwipeCoach = false
    @State private var showTapCoach = false

    // Videos scoped to the active style mode. The feed and library share this lens.
    private var videos: [Video] {
        allVideos.filter { styleStore.matches($0) }
    }

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

    /// True while either coach beat is on screen. Hides all non-video chrome
    /// and the native tab bar so the lesson is the only thing visible.
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
            .toolbar(coachActive ? .hidden : .automatic, for: .tabBar)
            // Keep global navigation tied to the system appearance instead of
            // letting the feed's full-bleed video backdrop drive the tab bar.
            .toolbarColorScheme(systemColorScheme, for: .tabBar)
            .navigationDestination(isPresented: $showDetail) {
                if let selectedVideo {
                    VideoDetailView(
                        video: selectedVideo,
                        startTime: editorStartTime,
                        onFinish: { newMarkedTime in
                            if let t = newMarkedTime {
                                editorStartTime = t
                            }
                        }
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
            }
        }
    }

    // Import pipeline + base gesture layer. Extracted to keep `body`'s modifier
    // chain short enough for the type checker.
    private var baseFeed: some View {
        GeometryReader { geo in
            feedRoot
                .gesture(feedDragGesture(width: geo.size.width, height: geo.size.height), including: showDetail ? .subviews : .all)
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
    }

    var body: some View {
        baseFeed
        .onAppear {
            Style.seedDefaultsIfNeeded(in: modelContext)
            styleStore.rehydrateIfNeeded(in: modelContext)
            syncWindow(autoplay: true)
            maybeAdvanceCoach()
        }
        .onChange(of: router.selectedTab) { _, new in
            if new == .feed {
                resumeFeedAfterPane()
            } else {
                activeController?.pause()
            }
        }
        .onChange(of: router.pendingFeedSelection) { _, selection in
            guard let selection else { return }
            applyPendingSelection(selection)
            router.pendingFeedSelection = nil
        }
        .onChange(of: router.addVideoRequested) { _, requested in
            guard requested else { return }
            showAddVideoDialog = true
            router.addVideoRequested = false
        }
        .onChange(of: selectedIndex) { _, _ in syncWindow(autoplay: true) }
        .onChange(of: styleStore.activeStyle) { _, _ in
            selectedIndex = 0
            syncWindow(autoplay: router.selectedTab == .feed)
        }
        .onChange(of: videos.count) { _, _ in
            normalizeSelectionAfterDataChange()
            maybeAdvanceCoach()
        }
        .onChange(of: activeController?.currentTime) { _, time in updateActiveMove(for: time ?? 0) }
        .onChange(of: showDetail) { _, presenting in
            router.hidesBottomChrome = coachActive || presenting
            if !presenting {
                ensureFeedSurface()
                if let t = editorStartTime, t.isFinite, t >= 0 {
                    activeController?.seek(to: t)
                }
                editorStartTime = nil
                activeController?.play()
            }
        }
        .onChange(of: showSwipeCoach) { _, _ in
            router.hidesBottomChrome = coachActive || showDetail
        }
        .onChange(of: showTapCoach) { _, _ in
            router.hidesBottomChrome = coachActive || showDetail
        }
        .onChange(of: activeVideoID) { _, new in
            router.currentFeedVideoID = new
        }
        .onChange(of: activeMoveID) { _, new in
            router.currentFeedMoveID = new
        }
    }

    private func feedSurface(for video: Video) -> some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            videoStack(height: fullHeight, width: geo.size.width, topInset: geo.safeAreaInsets.top, bottomInset: geo.safeAreaInsets.bottom)
                .contentShape(Rectangle())
        }
    }

    /// Empty-state CTA card shown when the current video has no moves yet.
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
        guard !showDetail else { return false }
        return video.movesSorted.isEmpty
    }

    private func videoStack(height: CGFloat, width: CGFloat, topInset: CGFloat, bottomInset: CGFloat) -> some View {
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

                    if isActive {
                        tapZones
                            .allowsHitTesting(!coachActive)
                    }

                    cardChromeStack(for: video, isActive: isActive, fullHeight: height, topInset: topInset, bottomInset: bottomInset)
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

    @ViewBuilder
    private func cardChromeStack(for video: Video, isActive: Bool, fullHeight: CGFloat, topInset: CGFloat, bottomInset: CGFloat) -> some View {
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
                        .padding(.bottom, bottomInset + Spacing.bottomBarClearance)
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
        // The invisible thirds carry no labels, so VoiceOver can't reach the
        // edge-tap move nav. Collapse them into one element and expose the same
        // three functions the taps call as named actions (no parallel path).
        .accessibilityElement()
        .accessibilityLabel("Move navigation")
        .accessibilityAction(named: "Previous move") {
            jumpToPreviousMove()
            dismissTapCoach()
        }
        .accessibilityAction(named: "Play or pause") { togglePlayback() }
        .accessibilityAction(named: "Next move") {
            jumpToNextMove()
            dismissTapCoach()
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
                Text("567 becomes a full-screen feed: swipe between videos, tap through moves, and use the Library tab for all your content.")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            maybeAdvanceCoach()
        }
    }

    private func dismissTapCoach() {
        guard showTapCoach else { return }
        hasSeenFeedTapCoach = true
        withAnimation(.easeInOut(duration: 0.25)) { showTapCoach = false }
    }

    // MARK: - Feed drag gesture (vertical paging + horizontal scrub)

    private func feedDragGesture(width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !showDetail else { return }
                if isVerticalDrag == nil {
                    isVerticalDrag = abs(value.translation.height) >= abs(value.translation.width)
                }
                if isVerticalDrag == true {
                    dragOffset = value.translation.height
                    startNeighborPlayback()
                } else {
                    updateScrub(translation: value.translation.width, locationX: value.location.x, width: width)
                }
            }
            .onEnded { value in
                defer { isVerticalDrag = nil }
                guard !showDetail else {
                    withAnimation(.snappy(duration: 0.28, extraBounce: 0.05)) { dragOffset = 0 }
                    return
                }
                if isVerticalDrag == true {
                    endVerticalSwipe(value: value, height: height)
                } else if isVerticalDrag == false {
                    endScrub()
                }
            }
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

    // MARK: - Horizontal scrub

    /// How many seconds of the clip a full-screen-width drag travels. Anchored at
    /// the playhead when the gesture began, so a small swipe nudges and a big
    /// swipe travels far ("relative / velocity-scaled"). Short clips map roughly
    /// 1:1 across the screen; longer clips cap so a single pass stays controllable
    /// and you scrub in multiple swipes.
    private func scrubSpan(for duration: TimeInterval) -> TimeInterval {
        max(12, min(duration, 75))
    }

    private func updateScrub(translation: CGFloat, locationX: CGFloat, width: CGFloat) {
        guard let controller = activeController, width > 0 else { return }
        let duration = effectiveDuration(for: selectedVideo)
        guard duration > 0 else { return }

        if !isScrubbing {
            isScrubbing = true
            scrubStartTime = controller.currentTime
            scrubWasPlaying = controller.isPlaying
            scrubLastMoveID = activeMoveID
            controller.pause()
            // Lift the move-range loop clamp so seeking can cross boundaries
            // without the loop observer snapping us back to the move start.
            controller.setActiveRange(start: nil, end: nil)
            Haptics.light()
        }

        let raw: TimeInterval
        switch Self.scrubMapping {
        case .relative:
            // Anchored at the playhead; drag delta scaled by the tuned span.
            raw = scrubStartTime + Double(translation / width) * scrubSpan(for: duration)
        case .absolute:
            // Finger X maps straight to the timeline — jumps to the finger on touch.
            raw = Double(locationX / width) * duration
        }
        let target = max(0, min(duration, raw))
        controller.seek(to: target)
        updateScrubHighlight(for: target)
    }

    /// Moves the rail highlight and ticks when the playhead crosses into a new
    /// move during a scrub, without re-arming the loop range (that waits for
    /// release so seeking stays free across boundaries).
    private func updateScrubHighlight(for time: TimeInterval) {
        guard !activeMoves.isEmpty else { return }
        let duration = effectiveDuration(for: selectedVideo)
        let landedID = moveContaining(time, duration: duration)?.id
        guard landedID != scrubLastMoveID else { return }
        scrubLastMoveID = landedID
        if let landedID {
            withTransaction(Transaction(animation: nil)) { activeMoveID = landedID }
        }
        Haptics.select()
    }

    private func endScrub() {
        guard isScrubbing, let controller = activeController else {
            isScrubbing = false
            return
        }
        isScrubbing = false
        scrubLastMoveID = nil
        let duration = effectiveDuration(for: selectedVideo)

        // Re-bind to whatever move the playhead landed in — re-arms the loop
        // boundary — but keep the scrubbed position rather than snapping to the
        // move start. A grace window guards against the periodic time observer
        // briefly reading a pre-seek value and flipping the highlight back.
        if let move = moveContaining(controller.currentTime, duration: duration) {
            manualMoveSelection = ManualMoveSelection(move: move)
            withTransaction(Transaction(animation: nil)) { activeMoveID = move.id }
            controller.setActiveRange(start: move.time, end: move.endTime)
        } else {
            controller.setActiveRange(start: 0, end: duration)
        }

        if scrubWasPlaying { controller.play() }
        Haptics.light()
    }

    private func moveContaining(_ time: TimeInterval, duration: TimeInterval) -> Move? {
        activeMoves.first { move in
            let end = move.endTime ?? duration
            return move.time <= time && time < max(move.time, end)
        }
    }

    // MARK: - Feed navigation

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

    /// Translates a router selection intent into local `pendingFeedMove` + `selectedIndex`.
    private func applyPendingSelection(_ selection: FeedSelection) {
        guard let idx = videos.firstIndex(where: { $0.id == selection.videoID }) else { return }
        if let moveID = selection.moveID,
           let move = videos[idx].movesSorted.first(where: { $0.id == moveID }) {
            pendingFeedMove = PendingFeedMove(videoID: selection.videoID, moveID: moveID, time: move.time, endTime: move.endTime)
        }
        if idx == selectedIndex {
            resumeFeedAfterPane()
        } else {
            selectedIndex = idx
        }
        Haptics.light()
    }

    private func openEditor() {
        guard selectedVideo != nil else { return }
        ensureFeedSurface()
        editorStartTime = activeController?.currentTime
        activeController?.pause()
        showDetail = true
    }

    private func ensureFeedSurface() {
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
        controller.isMuted = session.isMuted
        if isNewActive {
            activeMoveID = nil
            if let first = video.movesSorted.first {
                activeMoveID = first.id
                controller.setActiveRange(start: first.time, end: first.endTime)
            } else {
                controller.setActiveRange(start: 0, end: effectiveDuration(for: video))
            }
        }
        if autoplay { controller.play() }

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
        if activeMoveIndex == activeMoves.count - 1 {
            play(activeMoves[0])
        } else {
            play(activeMoves[activeMoveIndex + 1])
        }
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
        guard !isScrubbing else { return }
        guard !activeMoves.isEmpty else { return }
        if let selection = manualMoveSelection {
            if selection.isExpired {
                manualMoveSelection = nil
            } else if !selection.contains(time) {
                return
            }
        }
        let duration = effectiveDuration(for: selectedVideo)
        guard let current = moveContaining(time, duration: duration) else { return }
        if current.id != activeMoveID {
            activeMoveID = current.id
            activeController?.setActiveRange(start: current.time, end: current.endTime)
        }
    }

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
