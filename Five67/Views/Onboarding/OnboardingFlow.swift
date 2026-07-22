import Photos
import PhotosUI
import SwiftData
import SwiftUI

struct OnboardingFlow: View {
    let onComplete: (UUID?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore
    @Environment(UnlockStore.self) private var unlockStore
    @Query(sort: \Video.importedAt, order: .reverse) private var allVideos: [Video]

    @State private var beat: Beat = .hook
    @State private var selectedValueProps: Set<String> = []
    @State private var painCardIndex = 0
    @State private var selectedStyles: Set<String> = []
    @State private var selectedVolume: String?
    @State private var showSeedPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImportingSeed = false
    @State private var importError: String?
    @State private var photosStatus: PHAuthorizationStatus?
    @State private var importedVideo: Video?
    @State private var navigationDirection: NavigationDirection = .forward

    private let preferences = OnboardingPreferences()

    var body: some View {
        Group {
            if beat == .editor, let importedVideo {
                editorBeat(video: importedVideo)
            } else {
                onboardingScaffold {
                    beatContent
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: Spacing.none) {
            if beat == .styles {
                styleContinueBar
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
            }
        }
        .background(onboardingBackground.ignoresSafeArea())
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
            // Onboarding answers are session-only by contract: they shape the
            // narrative and are never persisted as analytics/research. A relaunch
            // therefore restarts the narrative with empty selections — but the
            // seed video itself survives and is reused.
            Style.seedDefaultsIfNeeded(in: modelContext)
            restorePersistedSeedIfAvailable()
        }
    }

    private var onboardingBackground: Color {
        Theme.stageBackground
    }

    private var selectedStyleName: String? {
        styleOptions.first(where: selectedStyles.contains)
    }

    private var onboardingAccent: Color {
        selectedStyleName.flatMap { StyleAccentPalette.accent(forName: $0)?.color }
            ?? Theme.stagePrimary
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
        case .hook:
            hookBeat
        case .valueSurvey:
            valueSurveyBeat
        case .pain:
            painBeat
        case .styles:
            stylesBeat
        case .volume:
            volumeBeat
        case .payoff:
            payoffBeat
        case .permission:
            permissionBeat
        case .seedImport:
            seedImportBeat
        case .editor:
            EmptyView()
        case .processing:
            processingBeat
        case .paywall:
            paywallBeat
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

            OnboardingProgressDots(currentIndex: beat.progressIndex, accent: onboardingAccent)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .foregroundStyle(Theme.stagePrimary)
        .background(onboardingBackground.opacity(0.96))
    }

    private var canGoBack: Bool {
        beat.rawValue > Beat.hook.rawValue && beat.rawValue <= Beat.payoff.rawValue
    }

    private var hookBeat: some View {
        VStack(spacing: Spacing.xl4) {
            OnboardingBrandHero(reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity)
                .frame(height: 320)

            VStack(spacing: Spacing.md) {
                Text("Your class videos finally have a home.")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Turn the dance clips buried in your camera roll into a move library you'll actually practice.")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            primaryButton("Get started") { goNext() }
        }
    }

    private var valueSurveyBeat: some View {
        optionBeat(
            title: "What do you want 567 for?",
            subtitle: nil,
            options: valuePropOptions,
            selected: selectedValueProps,
            continueTitle: "Continue",
            toggle: toggleValueProp,
            continueAction: {
                goNext()
            }
        )
    }

    private var painBeat: some View {
        VStack(alignment: .leading, spacing: Spacing.xl3) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sound familiar?")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(painCardIndex + 1) of 2")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .accessibilityLabel("Pain card \(painCardIndex + 1) of 2")
            }

            painCard(
                number: painCardIndex == 0 ? "01" : "02",
                title: painCardIndex == 0
                    ? "You record every class… and never watch them again."
                    : "A week later the move's gone — and the video's lost in 2,000 camera-roll clips."
            )
            .id(painCardIndex)
            .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .trailing)))

            primaryButton(painCardIndex == 0 ? "Keep going" : "That's me") {
                if painCardIndex == 0 {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
                        painCardIndex = 1
                    }
                } else {
                    goNext()
                }
            }
        }
    }

    private func painCard(number: String, title: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(number)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(Theme.stageSecondary)
                .frame(width: 30, alignment: .leading)

            VStack(alignment: .leading, spacing: Spacing.xsPlus) {
                Text(title)
                    .font(.headline.weight(.bold))
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.stageStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var stylesBeat: some View {
        VStack(alignment: .leading, spacing: Spacing.xl3) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("What do you dance most?")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.stagePrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Choose where you want your library to start. You can change this later.")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Spacing.smPlus) {
                ForEach(styleOptions, id: \.self) { style in
                    StageSelectableRow(
                        title: style == "Other" ? "Something else" : style,
                        identityColor: StyleAccentPalette.accent(forName: style)?.color,
                        isSelected: selectedStyles.contains(style)
                    ) {
                        toggleStyle(style)
                    }
                }
            }
        }
    }

    private var styleContinueBar: some View {
        VStack(spacing: Spacing.none) {
            Button {
                activateSelectedStyle()
                goNext()
            } label: {
                HStack(spacing: Spacing.md) {
                    Text("Continue")

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.black))
                }
            }
            .buttonStyle(StagePrimaryActionButtonStyle())
            .accessibilityHint("Continues to the next onboarding step")
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
        }
        .background(Theme.stageBackground.opacity(0.96))
    }

    private var volumeBeat: some View {
        optionBeat(
            title: "How many class videos are sitting in your camera roll right now?",
            subtitle: nil,
            options: volumeOptions,
            selected: Set(selectedVolume.map { [$0] } ?? []),
            continueTitle: "Continue",
            toggle: { selectedVolume = $0 },
            continueAction: {
                goNext()
            }
        )
    }

    private var payoffBeat: some View {
        VStack(spacing: Spacing.xl4) {
            OnboardingPayoffArtwork(reduceMotion: reduceMotion)
                .frame(height: 320)

            VStack(spacing: Spacing.md) {
                Text("This is what they become.")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                Text("Clipped. Named. Looping. Ready to practice in seconds.")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
            }

            primaryButton("Show me how") { goNext() }
        }
    }

    private var permissionBeat: some View {
        VStack(alignment: .leading, spacing: Spacing.xl4) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Let's find your class videos.")
                    .font(.largeTitle.weight(.heavy))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    BulletLine("Pulls your dance clips straight from Photos — no hunting")
                    BulletLine("Everything stays on your device. Private by design.")
                    BulletLine("We only touch the videos you choose to save")
                }
                .foregroundStyle(Theme.stageSecondary)
                .padding(.top, Spacing.sm)

                if photosStatus == .limited {
                    Text("Limited access is okay here. You can still pick a class video manually.")
                        .font(.footnote)
                        .foregroundStyle(Theme.stageSecondary)
                        .padding(.top, Spacing.sm)
                }
            }

            primaryButton("Connect my videos") {
                Task { await requestPhotoAccess() }
            }
        }
    }

    private var seedImportBeat: some View {
        VStack(spacing: Spacing.xl4) {
            Image(systemName: "film.stack")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(onboardingAccent)
                .frame(height: 110)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.md) {
                Text("Pick a video from your recent classes.")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Start with one — we'll turn it into your first moves.")
                    .font(.body)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
            }

            if photosStatus == .denied || photosStatus == .restricted {
                Text("You can still choose a video with Apple's private picker. 567 only receives the video you select.")
                    .font(.footnote)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
            }

            primaryButton(isImportingSeed ? "Saving..." : "Choose video") {
                showSeedPicker = true
            }
            .disabled(isImportingSeed)
        }
    }

    private var processingBeat: some View {
        VStack(spacing: Spacing.xl4) {
            ProcessingMark(reduceMotion: reduceMotion)
                .frame(width: 120, height: 120)
                .padding(.top, Spacing.xl5)

            Text("Building your library…")
                .font(.largeTitle.weight(.heavy))
                .multilineTextAlignment(.center)
        }
        .task {
            let delay: UInt64 = reduceMotion ? 1_000_000_000 : 1_800_000_000
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                if beat == .processing {
                    beat = .paywall
                }
            }
        }
    }

    private var paywallBeat: some View {
        UnlockPaywallView(
            reason: .onboarding,
            secondaryTitle: "Maybe later",
            onUnlocked: { complete() },
            onSecondary: { complete() }
        )
    }

    private func editorBeat(video: Video) -> some View {
        ZStack(alignment: .bottom) {
            VideoDetailView(
                video: video,
                finishTitle: "Done",
                showsTitle: false,
                onFinish: { _ in
                    beat = .processing
                }
            )

            OnboardingProgressDots(currentIndex: beat.progressIndex, accent: onboardingAccent)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .liquidGlass(in: Capsule())
                .padding(.bottom, Spacing.md)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func optionBeat(
        title: String,
        subtitle: String?,
        options: [String],
        selected: Set<String>,
        continueTitle: String,
        toggle: @escaping (String) -> Void,
        continueAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xl4) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title)
                    .font(.largeTitle.weight(.heavy))
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Theme.stageSecondary)
                }
            }

            VStack(spacing: Spacing.md) {
                ForEach(options, id: \.self) { option in
                    StageSelectableRow(
                        title: option,
                        accessibilityTitle: accessibleOptionTitle(option),
                        isSelected: selected.contains(option),
                    ) {
                        toggle(option)
                    }
                }
            }

            primaryButton(continueTitle, action: continueAction)
        }
    }

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

    private func accessibleOptionTitle(_ title: String) -> String {
        guard let firstSpace = title.firstIndex(of: " ") else { return title }
        let prefix = title[..<firstSpace]
        guard prefix.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) else {
            return title
        }
        return String(title[title.index(after: firstSpace)...])
    }

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

    private func complete() {
        activateSelectedStyle()
        preferences.markCompleted()
        onComplete(importedVideo?.id)
    }

    private func toggleValueProp(_ value: String) {
        if selectedValueProps.contains(value) {
            selectedValueProps.remove(value)
        } else {
            selectedValueProps.insert(value)
        }
        Haptics.select()
    }

    private func toggleStyle(_ value: String) {
        if selectedStyles.contains(value) {
            selectedStyles.removeAll()
        } else {
            selectedStyles = [value]
        }
        Haptics.select()
    }

    /// Resolves the onboarding choice into the same persisted Style model used
    /// by the global app filter. Non-seeded options become ordinary user
    /// styles; choosing "Something else" leaves the app in neutral All mode.
    @discardableResult
    private func activateSelectedStyle() -> Style? {
        guard let selectedStyleName, selectedStyleName != "Other" else {
            styleStore.activeStyle = nil
            return nil
        }

        let descriptor = FetchDescriptor<Style>()
        let styles = (try? modelContext.fetch(descriptor)) ?? []
        let style: Style
        if let existing = styles.first(where: {
            $0.name.localizedCaseInsensitiveCompare(selectedStyleName) == .orderedSame
        }) {
            style = existing
        } else {
            style = Style(name: selectedStyleName)
            modelContext.insert(style)
        }

        styleStore.activeStyle = style
        unlockStore.recordStyleUse(style.id)
        try? modelContext.save()
        return style
    }

    private func requestPhotoAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            photosStatus = status
            goNext()
        }
    }

    private func importSeedVideo(_ item: PhotosPickerItem) async {
        isImportingSeed = true
        defer { isImportingSeed = false }

        let existingSourceIDs = Dictionary(uniqueKeysWithValues: allVideos.compactMap { video in
            video.sourceAssetID.map { ($0, video.id) }
        })

        do {
            let result = try await VideoImporter.import(from: item, existingSourceIDs: existingSourceIDs)
            let video = VideoImportPersistence.insertVideo(from: result, in: modelContext)
            video.style = styleStore.activeStyle
            try? modelContext.save()
            adoptSeed(video)
            Haptics.success()
            beat = .editor
        } catch ImportError.alreadyImported(let existingID) {
            if let existing = allVideos.first(where: { $0.id == existingID }) {
                adoptSeed(existing)
                beat = .editor
            } else {
                importError = "This video is already in your library."
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Records the seed so an interrupted onboarding reuses it instead of
    /// importing a duplicate when it reaches Seed again.
    private func adoptSeed(_ video: Video) {
        importedVideo = video
        preferences.saveSeedVideoID(video.id)
    }

    /// Resolves a previously persisted seed. Clears the stored ID when the row
    /// or its file has gone missing so Seed falls back to its normal actions.
    private func restorePersistedSeedIfAvailable() {
        guard importedVideo == nil, let seedID = preferences.seedVideoID else { return }
        guard let video = allVideos.first(where: { $0.id == seedID }),
              FileManager.default.fileExists(atPath: video.fileURL.path) else {
            preferences.clearSeedVideoID()
            return
        }
        importedVideo = video
    }

    private let valuePropOptions = [
        "🧠 Remember the moves I've learned",
        "🔁 Practice the moves I'm working on",
        "🗂️ Keep my class videos organized",
        "💃 Stop losing steps between classes",
        "🎯 Actually review what I record"
    ]

    private let styleOptions = [
        "Salsa",
        "Bachata",
        "Cumbia",
        "Kizomba",
        "Zouk",
        "Merengue",
        "Other"
    ]

    private let volumeOptions = [
        "A handful (1–10)",
        "A stash (10–50)",
        "A graveyard (50+)",
        "I've lost count"
    ]
}

private enum Beat: Int, CaseIterable {
    case hook
    case valueSurvey
    case pain
    case styles
    case volume
    case payoff
    case permission
    case seedImport
    case editor
    case processing
    case paywall

    var progressIndex: Int { rawValue }
}

private enum NavigationDirection {
    case forward
    case backward
}

private struct OnboardingProgressDots: View {
    let currentIndex: Int
    let accent: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<Beat.allCases.count, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? accent : Theme.stageSecondary.opacity(0.25))
                    .frame(width: index == currentIndex ? 18 : 6, height: 6)
            }
        }
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentIndex + 1) of \(Beat.allCases.count)")
    }
}

struct BulletLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.body)
    }
}

private struct ProcessingMark: View {
    let reduceMotion: Bool
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.stageRaisedSurface, lineWidth: 12)
            Circle()
                .trim(from: 0.1, to: 0.72)
                .stroke(StyleAccentPalette.salsa.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(rotation))
            Image(systemName: "sparkles")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.stagePrimary)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .accessibilityHidden(true)
    }
}
