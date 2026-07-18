import SwiftUI
import SwiftData

enum PaneTab: String, CaseIterable, Identifiable {
    case moves, videos
    var id: String { rawValue }
    var label: String {
        switch self {
        case .moves:  return "Moves"
        case .videos: return "Videos"
        }
    }
}

private struct PaneMoveGroup: Identifiable {
    let id: String
    let title: String
    let sortDate: Date
    let moves: [Move]
}

/// Library tab. Consolidates the Videos list and the Moves-grouped-by-video
/// list into one surface, scoped by the global style mode. Tapping a row hands
/// selection back to the feed via callbacks wired in RootView.
struct LibraryPaneView: View {
    private enum AccessibilityFocus: Hashable {
        case header
        case move(UUID)
        case video(UUID)
    }

    let activeVideoID: UUID?
    let activeMoveID: UUID?
    let onSelectVideo: (Video) -> Void
    let onSelectMove: (Move) -> Void
    let onImportPhotos: () -> Void
    let onImportFiles: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(AppRouter.self) private var router

    @Query(sort: [SortDescriptor(\Video.importedAt, order: .reverse)])
    private var allVideos: [Video]

    @AppStorage("libraryPaneTab") private var tab: PaneTab = .moves
    @State private var search = ""
    @AccessibilityFocusState private var accessibilityFocus: AccessibilityFocus?

    @State private var deleteVideoTarget: Video?
    @State private var showDeleteVideoConfirm = false

    // Export
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportDocument: LibraryExportDocument?
    @State private var pendingExportResult: LibraryExportResult?
    @State private var lastExportResult: LibraryExportResult?
    @State private var showExporterSheet = false
    @State private var showExportSummary = false
    @State private var showExportTypeDialog = false

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var styleVideos: [Video] {
        allVideos.filter { styleStore.matches($0) }
    }

    private var searchedVideos: [Video] {
        guard !trimmedSearch.isEmpty else { return styleVideos }
        return styleVideos.filter { $0.displayName.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    private var moveGroups: [PaneMoveGroup] {
        var groups: [PaneMoveGroup] = []
        for video in styleVideos {
            let videoMatches = trimmedSearch.isEmpty
                || video.displayName.localizedCaseInsensitiveContains(trimmedSearch)
            let moves = video.movesSorted.filter { move in
                if trimmedSearch.isEmpty { return true }
                return videoMatches || move.name.localizedCaseInsensitiveContains(trimmedSearch)
            }
            guard !moves.isEmpty else { continue }
            groups.append(
                PaneMoveGroup(
                    id: video.id.uuidString,
                    title: groupTitle(for: video),
                    sortDate: video.recordedAt ?? video.importedAt,
                    moves: moves
                )
            )
        }
        return groups.sorted { $0.sortDate > $1.sortDate }
    }

    private var isEmpty: Bool { styleVideos.isEmpty }

    private var accentColor: Color {
        styleStore.accent?.color ?? Theme.stagePrimary
    }

    private var stageStroke: Color {
        colorSchemeContrast == .increased ? Theme.stageSecondary.opacity(0.5) : Theme.stageStroke
    }

    var body: some View {
        VStack(spacing: Spacing.none) {
            libraryHeader
                .padding(.top, Spacing.lg)
            tabPicker
            searchField
            content
        }
        .foregroundStyle(Theme.stagePrimary)
        .background(Theme.stageBackground)
        .preferredColorScheme(.dark)
        .photosExportAttachments(
            isExporting: $isExporting,
            showExportTypeDialog: $showExportTypeDialog,
            showExporterSheet: $showExporterSheet,
            showExportSummary: $showExportSummary,
            exportDocument: exportDocument,
            exportError: $exportError,
            lastExportResult: lastExportResult,
            defaultFilename: defaultExportFilename(),
            onFullExport: { Task { await runExport(includeVideos: true) } },
            onMetadataExport: { Task { await runExport(includeVideos: false) } },
            onExporterResult: handleExporterResult
        )
        .confirmationDialog(
            "Delete \"\(deleteVideoTarget?.displayName ?? "")\"?",
            isPresented: $showDeleteVideoConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Video & Moves", role: .destructive) {
                if let v = deleteVideoTarget { deleteVideo(v) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let video = deleteVideoTarget {
                Text(deletionImpactMessage(for: video))
            }
        }
        .onAppear(perform: focusPendingArrival)
        .onChange(of: router.pendingLibraryArrival) { _, _ in
            focusPendingArrival()
        }
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Text("Library")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-0.8)
                .accessibilityFocused($accessibilityFocus, equals: .header)

            Spacer()

            HStack(spacing: Spacing.sm) {
                if styleStore.activeStyle != nil {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                }
                Text(styleStore.label)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Theme.stagePrimary)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 36)
            .background(Theme.stageSurface, in: Capsule())
            .overlay { Capsule().stroke(stageStroke, lineWidth: 1) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Style filter: \(styleStore.label)")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private var tabPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(PaneTab.allCases) { t in
                Button {
                    if reduceMotion {
                        tab = t
                    } else {
                        withAnimation(.snappy(duration: 0.24, extraBounce: 0.03)) {
                            tab = t
                        }
                    }
                } label: {
                    Text(t.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.stageSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            tab == t ? Theme.stageRaisedSurface : Color.clear,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
                .accessibilityLabel(t.label)
                .accessibilityValue(tab == t ? "Selected" : "")
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .padding(Spacing.xs)
        .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(stageStroke, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.smPlus)
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.stageSecondary)
            TextField("Search moves and videos", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: search) { _, new in
                    if new.count > 80 { search = String(new.prefix(80)) }
                }
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.stageSecondary)
                }
                .buttonStyle(.plain)
                .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.mdPlus)
        .padding(.vertical, Spacing.smPlus)
        .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(stageStroke, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isEmpty {
            emptyState
        } else {
            ZStack {
                if tab == .moves {
                    movesList
                        .transition(modeTransition)
                } else {
                    videosList
                        .transition(modeTransition)
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.26), value: tab)
        }
    }

    private var modeTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return tab == .videos
            ? .asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading))
            : .asymmetric(insertion: .push(from: .leading), removal: .push(from: .trailing))
    }

    private var movesList: some View {
        List {
            ForEach(moveGroups) { group in
                Section {
                    ForEach(group.moves) { move in
                        MoveRowView(
                            move: move,
                            isActive: move.id == activeMoveID,
                            onTap: { onSelectMove(move) },
                            onDelete: { deleteMove(move) },
                            onRename: { newName in rename(move, to: newName) },
                            onExclude: { toggleExclude(move) },
                            accentColor: playbackAccent(for: move.video)
                        )
                        .accessibilityFocused($accessibilityFocus, equals: .move(move.id))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(stageStroke, lineWidth: 1)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(group.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.stageSecondary)
                        .textCase(nil)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
                }
                .listSectionSeparator(.hidden)
            }
            if moveGroups.isEmpty {
                ContentUnavailableView(
                    "No moves match",
                    systemImage: "music.note.list",
                    description: Text("Try a different filter, style, or search.")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(Spacing.sm)
        .scrollIndicators(.hidden)
        .contentMargins(.top, Spacing.none, for: .scrollContent)
        .contentMargins(.bottom, Spacing.bottomBarClearance, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.stageBackground)
    }

    private var videosList: some View {
        List {
            ForEach(searchedVideos) { video in
                Button {
                    onSelectVideo(video)
                } label: {
                    HStack(spacing: Spacing.md) {
                        VideoRowView(video: video)
                        if video.id == activeVideoID {
                            Image(systemName: "waveform")
                                .font(.body.weight(.bold))
                                .foregroundStyle(playbackAccent(for: video))
                                .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
                                .accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(Theme.stagePrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(stageStroke, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityValue(video.id == activeVideoID ? "Playing" : "")
                .accessibilityFocused($accessibilityFocus, equals: .video(video.id))
                .accessibilityAction(named: "Delete") {
                    deleteVideoTarget = video
                    showDeleteVideoConfirm = true
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button {
                        deleteVideoTarget = video
                        showDeleteVideoConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
            if searchedVideos.isEmpty {
                ContentUnavailableView(
                    "No videos match",
                    systemImage: "film.stack",
                    description: Text("Try a different style or search.")
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, Spacing.bottomBarClearance, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.stageBackground)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xl2) {
            Spacer(minLength: 0)
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Theme.stageSecondary)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xsPlus) {
                Text("Drop in a dance video")
                    .font(.title2.weight(.bold))
                Text("Import a practice video to start building your library.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.stageSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: Spacing.md) {
                Button {
                    onImportPhotos()
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(StagePrimaryActionButtonStyle())
                Button {
                    onImportFiles()
                } label: {
                    Label("Import from Files", systemImage: "folder")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.stagePrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal, Spacing.xl3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Move helpers

    private func focusPendingArrival() {
        guard let arrival = router.pendingLibraryArrival else { return }
        router.pendingLibraryArrival = nil

        Task { @MainActor in
            await Task.yield()
            guard let videoID = arrival.videoID else {
                accessibilityFocus = .header
                return
            }

            if tab == .moves,
               let move = moveGroups
                .flatMap(\.moves)
                .first(where: { $0.video?.id == videoID }) {
                accessibilityFocus = .move(move.id)
            } else if tab == .videos,
                      searchedVideos.contains(where: { $0.id == videoID }) {
                accessibilityFocus = .video(videoID)
            } else {
                accessibilityFocus = .header
            }
        }
    }

    private func groupTitle(for video: Video) -> String {
        let date = (video.recordedAt ?? video.importedAt).formatted(date: .long, time: .omitted)
        return "\(date) · \(video.style?.name ?? "Unsorted")"
    }

    private func playbackAccent(for video: Video?) -> Color {
        guard let video, let style = video.style else { return Theme.stagePrimary }
        return StyleAccentPalette.accent(forName: style.name, id: style.id)?.color ?? Theme.stagePrimary
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

    private func deleteMove(_ move: Move) {
        guard let video = move.video else {
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
        modelContext.delete(move)
        Haptics.medium()
    }

    private func deleteVideo(_ video: Video) {
        let videoID = video.id
        Task { await ThumbnailService.shared.clearCache(for: videoID) }
        try? FileManager.default.removeItem(at: video.fileURL)
        modelContext.delete(video)
        Haptics.medium()
    }

    private func deletionImpactMessage(for video: Video) -> String {
        let namedMoveCount = video.moves.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        if namedMoveCount == 0 {
            return "No named moves will be removed."
        }
        return "This also removes \(namedMoveCount) named \(namedMoveCount == 1 ? "move" : "moves") saved in this video."
    }

    // MARK: - Export

    private func handleExporterResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            lastExportResult = pendingExportResult
            showExportSummary = true
        case .failure(let err):
            if (err as NSError).code != NSUserCancelledError {
                exportError = err.localizedDescription
            }
        }
        pendingExportResult = nil
        exportDocument = nil
    }

    @MainActor
    private func runExport(includeVideos: Bool) async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        await Task.yield()

        do {
            try modelContext.save()
            let container = modelContext.container
            let result = try await Task.detached(priority: .userInitiated) {
                let exporter = LibraryExporter(modelContainer: container)
                return try await exporter.export(includeVideos: includeVideos)
            }.value
            pendingExportResult = result
            exportDocument = LibraryExportDocument(zipURL: result.zipURL)
            showExporterSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func defaultExportFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmm"
        let stem = (pendingExportResult?.includesVideoFiles ?? true) ? "Library" : "Metadata"
        return "567-\(stem)-\(df.string(from: Date()))"
    }
}

// MARK: - Export modifiers (kept off the main body for readability)

extension View {
    func photosExportAttachments(
        isExporting: Binding<Bool>,
        showExportTypeDialog: Binding<Bool>,
        showExporterSheet: Binding<Bool>,
        showExportSummary: Binding<Bool>,
        exportDocument: LibraryExportDocument?,
        exportError: Binding<String?>,
        lastExportResult: LibraryExportResult?,
        defaultFilename: String,
        onFullExport: @escaping () -> Void,
        onMetadataExport: @escaping () -> Void,
        onExporterResult: @escaping (Result<URL, Error>) -> Void
    ) -> some View {
        self
            .confirmationDialog(
                "Export Library",
                isPresented: showExportTypeDialog,
                titleVisibility: .visible
            ) {
                Button("Full Export (Videos + Metadata)", action: onFullExport)
                Button("Metadata Only (No Videos)", action: onMetadataExport)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Full exports include all video files and can be large. Metadata-only exports are quick and contain just your moves and library structure.")
            }
            .fileExporter(
                isPresented: showExporterSheet,
                document: exportDocument,
                contentType: .zip,
                defaultFilename: defaultFilename,
                onCompletion: onExporterResult
            )
            .alert(
                "Export failed",
                isPresented: Binding(
                    get: { exportError.wrappedValue != nil },
                    set: { if !$0 { exportError.wrappedValue = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError.wrappedValue ?? "")
            }
            .sheet(isPresented: showExportSummary) {
                if let result = lastExportResult {
                    PaneExportSummarySheet(result: result)
                }
            }
            .overlay {
                if isExporting.wrappedValue && !showExporterSheet.wrappedValue {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: Spacing.md) {
                            ProgressView().controlSize(.large)
                            Text("Preparing export…").font(.headline)
                            Text("This may take a moment for large libraries.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(Spacing.xl2)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(Spacing.xl5)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Preparing export")
                        .accessibilityValue("This may take a moment for large libraries")
                    }
                    .accessibilityAddTraits(.isModal)
                    .transition(.opacity)
                }
            }
    }
}

struct PaneExportSummarySheet: View {
    let result: LibraryExportResult
    @Environment(\.dismiss) private var dismiss
    @State private var detailsExpanded = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Export complete", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                Section("Contents") {
                    LabeledContent("Videos", value: "\(result.videoCount)")
                    LabeledContent("Moves",  value: "\(result.moveCount)")
                }
                Section("Integrity") {
                    LabeledContent("Missing files",   value: "\(result.missingFiles.count)")
                    LabeledContent("Orphan files",    value: "\(result.orphanFiles.count)")
                    LabeledContent("Orphan moves",    value: "\(result.orphanMoveCount)")
                    if result.hasIntegrityIssues {
                        DisclosureGroup("Show details", isExpanded: $detailsExpanded) {
                            if !result.missingFiles.isEmpty {
                                Text("Missing files").font(.subheadline.weight(.semibold))
                                ForEach(result.missingFiles, id: \.self) { name in
                                    Text(name).font(.footnote.monospaced())
                                }
                            }
                            if !result.orphanFiles.isEmpty {
                                Text("Orphan files").font(.subheadline.weight(.semibold))
                                ForEach(result.orphanFiles, id: \.self) { name in
                                    Text(name).font(.footnote.monospaced())
                                }
                            }
                            if result.orphanMoveCount > 0 {
                                Text("\(result.orphanMoveCount) move(s) have no associated video.")
                                    .font(.footnote)
                            }
                        }
                    } else {
                        Label("No issues found", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Export summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
