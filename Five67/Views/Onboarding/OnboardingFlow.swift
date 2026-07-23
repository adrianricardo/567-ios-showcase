import PhotosUI
import SwiftData
import SwiftUI

struct OnboardingFlow: View {
    /// Reports the onboarding result so the caller can land the Feed on it.
    /// Nil when the flow completed without a seed video (test fixtures only).
    let onComplete: (FeedSelection?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore
    @Environment(UnlockStore.self) private var unlockStore
    @Query(sort: \Video.importedAt, order: .reverse) private var allVideos: [Video]
    @Query(sort: \Style.createdAt, order: .forward) private var allStyles: [Style]

    @State private var beat: Beat = .hook
    @State private var motivation: OnboardingMotivation?
    @State private var showSeedPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImportingSeed = false
    @State private var importError: String?
    @State private var seedVideo: Video?
    @State private var showStyleTagSheet = false
    @State private var styleTagCreationRequested = false
    @State private var showAddStyleSheet = false
    @State private var createdStyleForSeed = false
    @State private var navigationDirection: NavigationDirection = .forward

    private let preferences = OnboardingPreferences()

    var body: some View {
        Group {
            if beat == .editor, let seedVideo {
                editorBeat(video: seedVideo)
            } else {
                onboardingScaffold {
                    beatContent
                }
            }
        }
        .background(Theme.stageBackground.ignoresSafeArea())
        .foregroundStyle(Theme.stagePrimary)
        .preferredColorScheme(.dark)
        .photosPicker(
            isPresented: $showSeedPicker,
            selection: $pickerItems,
            maxSelectionCount: 1,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .onChange(of: pickerItems) { _, items in
            guard let item = items.first else { return }
            pickerItems = []
            Task { await importSeedVideo(item) }
        }
        // The canonical post-import style sheet tags the onboarding seed before
        // the editor opens.
        .sheet(isPresented: $showStyleTagSheet, onDismiss: handleStyleTagSheetDismiss) {
            StyleSelectionSheet(
                context: .tagImport(count: 1),
                styles: allStyles,
                selectedStyleID: seedVideo?.style?.id,
                onSelect: applySeedStyle,
                onAddNewStyle: { styleTagCreationRequested = true }
            )
        }
        .sheet(isPresented: $showAddStyleSheet, onDismiss: handleAddStyleSheetDismiss) {
            RenameSheet(
                title: "New Style",
                isPresented: $showAddStyleSheet,
                initial: ""
            ) { newName in
                let style = Style(name: newName)
                modelContext.insert(style)
                applySeedStyle(style)
                try? modelContext.save()
                createdStyleForSeed = true
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-Five67UITestOnboardingCompletionFixture") {
                beat = .paywall
            }
#endif
            // The motivation answer is session-only by contract, so a relaunch
            // restarts the narrative at Hook with it cleared — but the seed
            // video itself survives and is reused when Seed is reached again.
            Style.seedDefaultsIfNeeded(in: modelContext)
            restorePersistedSeedIfAvailable()
        }
    }

    private var onboardingAccent: Color {
        guard let style = seedVideo?.style else { return Theme.stagePrimary }
        return StyleAccentPalette.accent(forName: style.name, id: style.id)?.color
            ?? Theme.stagePrimary
    }

    private var payoffAccent: Color {
        StyleAccentPalette.salsa.color
    }

    private var progressAccent: Color {
        beat == .payoff ? payoffAccent : onboardingAccent
    }

    private var beatTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        let insertionEdge: Edge = navigationDirection == .forward ? .trailing : .leading
        let removalEdge: Edge = navigationDirection == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var beatContent: some View {
        switch beat {
        case .hook:       hookBeat
        case .motivation: motivationBeat
        case .payoff:     payoffBeat
        case .seed:       seedBeat
        case .editor:     EmptyView()
        case .result:     resultBeat
        case .paywall:    paywallBeat
        }
    }

    private func onboardingScaffold<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: Spacing.none) {
            topBar
            ScrollView {
                VStack(spacing: Spacing.xl4) {
                    content()
                        .id(beat)
                        .transition(beatTransition)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl4)
                .padding(.bottom, Spacing.xl5)
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                if canGoBack {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    }
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                }

                Spacer()
            }

            OnboardingProgressDots(progress: beat.progress, accent: progressAccent)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .foregroundStyle(Theme.stagePrimary)
        .background(Theme.stageBackground.opacity(0.96))
    }

    /// Back is offered on every reversible state. The paywall is the one
    /// irreversible exit — leaving it *is* completion.
    private var canGoBack: Bool {
        beat != .hook && beat != .paywall
    }

    // MARK: - Beats

    private var hookBeat: some View {
        VStack(spacing: Spacing.xl3) {
            VStack(spacing: Spacing.md) {
                Text("Never forget a turn or combo again.")
                    .font(Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Turn class videos into named moves you can find, loop, and practice.")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image("OnboardingMoveCards")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Three saved dance moves organized by dance style")

            primaryButton("Get started") { goNext() }
        }
    }

    private var motivationBeat: some View {
        VStack(alignment: .leading, spacing: Spacing.xl4) {
            Text("What do you want 567 for?")
                .font(Typography.screenTitle)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Spacing.md) {
                ForEach(OnboardingMotivation.allCases) { option in
                    StageSelectableRow(
                        title: option.label,
                        isSelected: motivation == option
                    ) {
                        motivation = option
                        Haptics.select()
                    }
                }
            }

            primaryButton("Continue") { goNext() }
                .disabled(motivation == nil)
        }
    }

    private var payoffBeat: some View {
        VStack(spacing: Spacing.xl4) {
            VStack(spacing: Spacing.md) {
                Text(motivation?.payoffHeadline ?? "Give every class video a home.")
                    .font(Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(motivation?.payoffSupportingCopy
                     ?? OnboardingMotivation.organize.payoffSupportingCopy)
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            OnboardingProductPreview(
                reduceMotion: reduceMotion,
                accent: payoffAccent,
                showsUnnamedRow: true
            )
                .frame(maxWidth: .infinity)
                .frame(height: 380)

            primaryButton("Show me how") { goNext() }
        }
    }

    /// Seed selection. A restored seed is reused rather than re-imported, so an
    /// interrupted onboarding never duplicates content.
    @ViewBuilder
    private var seedBeat: some View {
        if let seedVideo {
            restoredSeedBeat(video: seedVideo)
        } else {
            newSeedBeat
        }
    }

    private var newSeedBeat: some View {
        VStack(spacing: Spacing.xl4) {
            Image(systemName: "film.stack")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.stagePrimary)
                .frame(height: 110)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.md) {
                Text("Pick a video from your recent classes.")
                    .font(Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Start with one — we'll turn it into your first move.")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            primaryButton(isImportingSeed ? "Saving…" : "Choose video") {
                showSeedPicker = true
            }
            .disabled(isImportingSeed)
        }
    }

    private func restoredSeedBeat(video: Video) -> some View {
        VStack(spacing: Spacing.xl4) {
            StageThumbnailView(
                videoID: video.id,
                fileURL: video.fileURL,
                size: CGSize(width: 220, height: 160),
                accent: onboardingAccent
            )

            VStack(spacing: Spacing.md) {
                Text("Your video's still here.")
                    .font(Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pick up where you left off with \(video.displayName).")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Spacing.md) {
                primaryButton("Continue") { openEditor() }

                secondaryButton("Choose a different video") {
                    showSeedPicker = true
                }
                .disabled(isImportingSeed)
            }
        }
    }

    @ViewBuilder
    private var resultBeat: some View {
        if let seedVideo, let move = resultMove(in: seedVideo) {
            OnboardingResultReveal(
                video: seedVideo,
                move: move,
                accent: onboardingAccent
            )

            primaryButton("Continue") { goNext() }
        } else {
            // Unreachable in the normal flow — both editor exits guarantee a
            // move — but a missing seed must never strand the user.
            primaryButton("Continue") { goNext() }
        }
    }

    private var paywallBeat: some View {
        UnlockPaywallView(
            reason: .onboarding,
            secondaryTitle: "Not now",
            onUnlocked: { complete() },
            onSecondary: { complete() }
        )
    }

    private func editorBeat(video: Video) -> some View {
        VideoDetailView(
            video: video,
            finishTitle: "Continue",
            secondaryFinishTitle: "I'll do this later",
            showsTitle: false,
            progress: Beat.editor.progress,
            onSecondaryFinish: { finishEditor() },
            onFinish: { _ in finishEditor() }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Shared controls

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(StagePrimaryActionButtonStyle())
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(StageSecondaryActionButtonStyle())
    }

    // MARK: - Navigation

    private func goNext() {
        if let next = Beat(rawValue: beat.rawValue + 1) {
            navigationDirection = .forward
            withAnimation(beatAnimation) {
                beat = next
            }
        }
        Haptics.light()
    }

    private func goBack() {
        if let previous = Beat(rawValue: beat.rawValue - 1) {
            navigationDirection = .backward
            withAnimation(beatAnimation) {
                beat = previous
            }
        }
        Haptics.light()
    }

    private var beatAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.32)
    }

    private func openEditor() {
        guard seedVideo != nil else { return }
        navigationDirection = .forward
        withAnimation(beatAnimation) {
            beat = .editor
        }
    }

    /// The single exit from the guided editor, shared by "Continue" and
    /// "I'll do this later". Both guarantee the reveal has a real move to loop.
    private func finishEditor() {
        ensureSeedMoveExists()
        navigationDirection = .forward
        withAnimation(beatAnimation) {
            beat = .result
        }
    }

    private func complete() {
        preferences.markCompleted()
        onComplete(resultSelection())
    }

    // MARK: - Seed video

    private func importSeedVideo(_ item: PhotosPickerItem) async {
        isImportingSeed = true
        defer { isImportingSeed = false }

        let existingSourceIDs = Dictionary(uniqueKeysWithValues: allVideos.compactMap { video in
            video.sourceAssetID.map { ($0, video.id) }
        })

        do {
            let result = try await VideoImporter.import(from: item, existingSourceIDs: existingSourceIDs)
            let video = VideoImportPersistence.insertVideo(from: result, in: modelContext)
            try? modelContext.save()
            adoptSeed(video)
            Haptics.success()
            // Personal imports are tagged through the canonical style sheet,
            // which opens the editor on dismissal.
            showStyleTagSheet = true
        } catch ImportError.alreadyImported(let existingID) {
            if let existing = allVideos.first(where: { $0.id == existingID }) {
                adoptSeed(existing)
                openEditor()
            } else {
                importError = "This video is already in your library."
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Applies the tagging sheet's choice. `recordStyleUse` is what claims the
    /// one free style, so it only ever runs for personal content.
    private func applySeedStyle(_ style: Style?) {
        guard let seedVideo else { return }
        unlockStore.recordStyleUse(style?.id)
        seedVideo.style = style
        styleStore.activeStyle = style
        try? modelContext.save()
    }

    private func handleStyleTagSheetDismiss() {
        guard styleTagCreationRequested else {
            openEditor()
            return
        }
        styleTagCreationRequested = false
        showAddStyleSheet = true
    }

    private func handleAddStyleSheetDismiss() {
        if createdStyleForSeed {
            createdStyleForSeed = false
            openEditor()
        } else {
            showStyleTagSheet = true
        }
    }

    /// Records the seed so an interrupted onboarding reuses it instead of
    /// importing a duplicate when it reaches Seed again.
    private func adoptSeed(_ video: Video) {
        seedVideo = video
        preferences.saveSeedVideoID(video.id)
    }

    /// Resolves a previously persisted seed. Clears the stored ID when the row
    /// or its file has gone missing so Seed falls back to its normal actions.
    private func restorePersistedSeedIfAvailable() {
        guard seedVideo == nil, let seedID = preferences.seedVideoID else { return }
        guard let video = allVideos.first(where: { $0.id == seedID }),
              FileManager.default.fileExists(atPath: video.fileURL.path) else {
            preferences.clearSeedVideoID()
            return
        }
        seedVideo = video
    }

    // MARK: - Result

    /// Guarantees one unnamed full-video move when the user left the editor
    /// without marking anything, so playback and the reveal still work. Never
    /// adds a duplicate.
    private func ensureSeedMoveExists() {
        guard let seedVideo, seedVideo.moves.isEmpty else { return }
        let duration = max(0, seedVideo.duration)
        modelContext.insert(
            Move(name: "", time: 0, endTime: duration, video: seedVideo)
        )
        try? modelContext.save()
    }

    /// The move the reveal loops and the Feed lands on: the first named move if
    /// there is one, otherwise the first move.
    private func resultMove(in video: Video) -> Move? {
        let sorted = video.movesSorted
        return sorted.first { !$0.name.isEmpty } ?? sorted.first
    }

    private func resultSelection() -> FeedSelection? {
        guard let seedVideo else { return nil }
        return FeedSelection(
            videoID: seedVideo.id,
            moveID: resultMove(in: seedVideo)?.id
        )
    }
}

/// The approved sequence. Progress stays in one top position across all of it,
/// including the guided editor.
private enum Beat: Int, CaseIterable {
    case hook
    case motivation
    case payoff
    case seed
    case editor
    case result
    case paywall

    var progress: OnboardingProgress {
        OnboardingProgress(index: rawValue, total: Beat.allCases.count)
    }
}

private enum NavigationDirection {
    case forward
    case backward
}

/// The real persisted move, looping on the real playback controller. Replaces
/// the former fake "Building your library…" processing beat.
private struct OnboardingResultReveal: View {
    let video: Video
    let move: Move
    let accent: Color

    @State private var controller: PlaybackController

    init(video: Video, move: Move, accent: Color) {
        self.video = video
        self.move = move
        self.accent = accent
        self._controller = State(wrappedValue: PlaybackController(videoURL: video.fileURL))
    }

    private var moveName: String {
        move.name.isEmpty ? "Unnamed move" : move.name
    }

    var body: some View {
        VStack(spacing: Spacing.xl3) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black)
                VideoPlayerSurface(controller: controller)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .frame(height: 320)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(moveName), looping")

            VStack(spacing: Spacing.md) {
                Text("Your first move is ready.")
                    .font(Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Label(moveName, systemImage: "repeat")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
        .onAppear {
            controller.isLooping = true
            controller.playRange(start: move.time, end: move.endTime)
        }
        .onDisappear {
            controller.pause()
        }
    }
}
