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

/// Swipe-in side pane co-equal to the feed. Consolidates the Videos list and
/// the Moves-grouped-by-video list into one surface, scoped by the global
/// style mode. Tapping a row hands selection back to the feed via callbacks.
struct LibraryPaneView: View {
    let activeVideoID: UUID?
    let activeMoveID: UUID?
    let onSelectVideo: (Video) -> Void
    let onSelectMove: (Move) -> Void
    let onImportPhotos: () -> Void
    let onImportFiles: () -> Void
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore

    @Query(sort: [SortDescriptor(\Video.importedAt, order: .reverse)])
    private var allVideos: [Video]

    @AppStorage("libraryPaneTab") private var tab: PaneTab = .moves
    @State private var search = ""

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

    var body: some View {
        VStack(spacing: Spacing.none) {
            tabPicker
                .padding(.top, Spacing.mdPlus)
            searchField
            content
        }
        .background(Color(.systemBackground))
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
        }
    }

    private var tabPicker: some View {
        Picker("View", selection: $tab) {
            ForEach(PaneTab.allCases) { t in
                Text(t.label).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.smPlus)
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.mdPlus)
        .padding(.vertical, Spacing.smPlus)
        .background(Color(.secondarySystemFill), in: Capsule())
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isEmpty {
            emptyState
        } else if tab == .moves {
            movesList
        } else {
            videosList
        }
    }

    private var movesList: some View {
        List {
            ForEach(moveGroups) { group in
                Section {
                    ForEach(group.moves) { move in
                        MoveRowView(
                            move: move,
                            isActive: activeMoveID == move.id,
                            onTap: { onSelectMove(move) },
                            onDelete: { deleteMove(move) },
                            onRename: { newName in rename(move, to: newName) },
                            onExclude: { toggleExclude(move) }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                } header: {
                    Text(group.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .listRowSeparator(.hidden)
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
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, Spacing.bottomBarTopOffset, for: .scrollContent)
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
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.xsPlus, leading: Spacing.lg, bottom: Spacing.xsPlus, trailing: Spacing.lg))
                .listRowBackground(
                    video.id == activeVideoID ? Color.accentColor.opacity(0.10) : Color.clear
                )
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
        .contentMargins(.bottom, Spacing.bottomBarTopOffset, for: .scrollContent)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xl2) {
            Spacer(minLength: 0)
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: Spacing.xsPlus) {
                Text("Drop in a dance video")
                    .font(.title2.weight(.bold))
                Text("Import a practice video to start building your library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: Spacing.md) {
                Button {
                    onImportPhotos()
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.primaryButtonHeight)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                Button {
                    onImportFiles()
                } label: {
                    Label("Import from Files", systemImage: "folder")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.primaryButtonHeight)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            .padding(.horizontal, Spacing.xl3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Move helpers

    private func groupTitle(for video: Video) -> String {
        (video.recordedAt ?? video.importedAt).formatted(date: .long, time: .omitted)
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
        return "Five67-\(stem)-\(df.string(from: Date()))"
    }
}

// MARK: - Export modifiers (kept off the main body for readability)

private extension View {
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
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isExporting.wrappedValue)
    }
}

private struct PaneExportSummarySheet: View {
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
