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
        .preferredColorScheme(beat == .styles ? .dark : nil)
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
            if ProcessInfo.processInfo.arguments.contains("-Five67UITestOnboardingCompletionFixture") {
                beat = .paywall
            }
            selectedValueProps = preferences.savedValueProps()
            let savedStyles = preferences.savedDanceStyles()
            selectedStyles = styleOptions.first(where: savedStyles.contains).map { [$0] } ?? []
            selectedVolume = preferences.savedVideoVolume()
            Style.seedDefaultsIfNeeded(in: modelContext)
        }
    }

    private var onboardingBackground: Color {
        beat == .styles ? Theme.stageBackground : Color(.systemBackground)
    }

    private var selectedStyleName: String? {
        styleOptions.first(where: selectedStyles.contains)
    }

    private var onboardingAccent: Color {
        beat == .styles ? Theme.stagePrimary : Color.accentColor
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
        .foregroundStyle(beat == .styles ? Theme.stagePrimary : Color.primary)
        .background(onboardingBackground.opacity(0.96))
    }

    private var canGoBack: Bool {
        beat.rawValue > Beat.hook.rawValue && beat.rawValue <= Beat.payoff.rawValue
    }

    private var hookBeat: some View {
        VStack(spacing: Spacing.xl4) {
            MockPhonePreview(reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity)
                .frame(height: 320)

            VStack(spacing: Spacing.md) {
                Text("Your class videos finally have a home.")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Turn the dance clips buried in your camera roll into a move library you'll actually practice.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
            allowsMultiple: true,
            continueTitle: "Continue",
            toggle: toggleValueProp,
            continueAction: {
                preferences.saveValueProps(selectedValueProps)
                goNext()
            }
        )
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
                    StageStyleRow(
                        title: style == "Other" ? "Something else" : style,
                        accent: StyleAccentPalette.accent(forName: style)?.color,
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
                preferences.saveDanceStyles(selectedStyles)
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
            allowsMultiple: false,
            continueTitle: "Continue",
            toggle: { selectedVolume = $0 },
            continueAction: {
                preferences.saveVideoVolume(selectedVolume)
                goNext()
            }
        )
    }

    private var payoffBeat: some View {
        VStack(spacing: Spacing.xl4) {
            PayoffLoopMock(reduceMotion: reduceMotion)
                .frame(height: 320)

            VStack(spacing: Spacing.md) {
                Text("This is what they become.")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                Text("Clipped. Named. Looping. Ready to practice in seconds.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.sm)

                if photosStatus == .limited {
                    Text("Limited access is okay here. You can still pick a class video manually.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.tint)
                .frame(height: 110)

            VStack(spacing: Spacing.md) {
                Text("Pick a video from your recent classes.")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Start with one — we'll turn it into your first moves.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
        VStack(spacing: Spacing.xl4) {
            VStack(spacing: Spacing.md) {
                Text("Pay once. Yours forever.")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Unlock unlimited moves — no subscription, ever.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                BulletLine("∞ Unlimited videos")
                BulletLine("🎨 Unlimited styles")
                BulletLine("☁️ iCloud cleanup (back up & clear your camera roll)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.secondaryChipFill))

            if let message = unlockStore.productLoadMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let message = unlockStore.purchaseMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.md) {
                primaryButton(unlockButtonTitle) {
                    Task {
                        if await unlockStore.purchase() {
                            complete()
                        }
                    }
                }
                .disabled(!unlockStore.canPurchase)

                secondaryButton("Maybe later") { complete() }

                Button("Restore purchase") {
                    Task {
                        if await unlockStore.restore() {
                            complete()
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minHeight: Spacing.touchTarget)
                .disabled(unlockStore.isRestoring)
            }
        }
        .task {
            if unlockStore.product == nil {
                await unlockStore.loadProduct()
            }
        }
    }

    private var unlockButtonTitle: String {
        if unlockStore.isPurchasing { return "Unlocking..." }
        if unlockStore.isLoadingProduct { return "Loading unlock..." }
        return "Unlock 567 — \(unlockStore.displayPrice)"
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
        allowsMultiple: Bool,
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
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: Spacing.md) {
                ForEach(options, id: \.self) { option in
                    OptionRow(
                        title: option,
                        isSelected: selected.contains(option),
                        allowsMultiple: allowsMultiple
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
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: Spacing.primaryButtonHeight)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: Spacing.primaryButtonHeight)
                .background(Theme.secondaryChipFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
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
        preferences.saveValueProps(selectedValueProps)
        preferences.saveDanceStyles(selectedStyles)
        preferences.saveVideoVolume(selectedVolume)
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
        preferences.saveValueProps(selectedValueProps)
        Haptics.select()
    }

    private func toggleStyle(_ value: String) {
        if selectedStyles.contains(value) {
            selectedStyles.removeAll()
        } else {
            selectedStyles = [value]
        }
        preferences.saveDanceStyles(selectedStyles)
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
            importedVideo = video
            Haptics.success()
            beat = .editor
        } catch ImportError.alreadyImported(let existingID) {
            importedVideo = allVideos.first { $0.id == existingID }
            if importedVideo == nil {
                importError = "This video is already in your library."
            } else {
                beat = .editor
            }
        } catch {
            importError = error.localizedDescription
        }
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
                    .fill(index <= currentIndex ? accent : Color.secondary.opacity(0.25))
                    .frame(width: index == currentIndex ? 18 : 6, height: 6)
            }
        }
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentIndex + 1) of \(Beat.allCases.count)")
    }
}

private struct OptionRow: View {
    let title: String
    let isSelected: Bool
    let allowsMultiple: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Image(systemName: isSelected ? selectedIcon : unselectedIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: Spacing.rowMinHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Theme.secondaryChipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedIcon: String {
        allowsMultiple ? "checkmark.square.fill" : "largecircle.fill.circle"
    }

    private var unselectedIcon: String {
        allowsMultiple ? "square" : "circle"
    }
}

private struct StageStyleRow: View {
    let title: String
    let accent: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Circle()
                    .fill(accent ?? Theme.stageSecondary)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.stagePrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                StageSelectionCheckmark(
                    isSelected: isSelected,
                    accent: accent ?? Theme.stagePrimary
                )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                Theme.stageSurface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.stageStroke, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(StageSelectableRowButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BulletLine: View {
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

private struct MockPhonePreview: View {
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.32), radius: 20, y: 12)

            VStack(spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.65), .orange.opacity(0.5), .blue.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Cross-body lead")
                                .font(.headline.weight(.heavy))
                            Text("0:14 loop")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .foregroundStyle(.white)
                        .padding(Spacing.lg)
                    }

                HStack(spacing: Spacing.sm) {
                    ForEach(["Basic", "Turn", "Lead"], id: \.self) { label in
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, Spacing.sm)
                            .frame(height: 26)
                            .background(.white.opacity(0.14), in: Capsule())
                    }
                }
                .foregroundStyle(.white)
            }
            .padding(Spacing.md)
            .scaleEffect(pulse ? 1.018 : 1)
        }
        .padding(.horizontal, Spacing.xl2)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct PayoffLoopMock: View {
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0.18

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.58), .pink.opacity(0.52), .cyan.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .center) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Inside turn")
                        .font(.title2.weight(.heavy))
                    Text("Looping move")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .foregroundStyle(.white)
                .padding(Spacing.lg)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(18, geo.size.width * progress))
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            if reduceMotion {
                progress = 0.72
            } else {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    progress = 0.92
                }
            }
        }
    }
}

private struct ProcessingMark: View {
    let reduceMotion: Bool
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 12)
            Circle()
                .trim(from: 0.1, to: 0.72)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(rotation))
            Image(systemName: "sparkles")
                .font(.title.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
