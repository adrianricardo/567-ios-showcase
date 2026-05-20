import SwiftUI
import SwiftData
import Photos
import PhotosUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Video.importedAt, order: .reverse) private var videos: [Video]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showFilesImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showError = false
    @State private var deleteTarget: Video?
    @State private var showDeleteConfirm = false

    // Export state
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportDocument: LibraryExportDocument?
    @State private var pendingExportResult: LibraryExportResult?
    @State private var lastExportResult: LibraryExportResult?
    @State private var showExporterSheet = false
    @State private var showExportSummary = false

    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(videos) { video in
                            NavigationLink(value: video) {
                                VideoRowView(video: video)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    deleteTarget = video
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cumbia Moves")
            .navigationDestination(for: Video.self) { video in
                VideoDetailView(video: video)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            Task { await runExport() }
                        } label: {
                            Label("Export Library…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isExporting)
                    } label: {
                        if isExporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showPhotosPicker = true
                        } label: {
                            Label("From Photos", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showFilesImporter = true
                        } label: {
                            Label("From Files", systemImage: "folder")
                        }
                    } label: {
                        if isImporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(isImporting)
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
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .fileExporter(
            isPresented: $showExporterSheet,
            document: exportDocument,
            contentType: .zip,
            defaultFilename: defaultExportFilename()
        ) { result in
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
        .sheet(isPresented: $showExportSummary) {
            if let result = lastExportResult {
                ExportSummarySheet(result: result)
            }
        }
        .confirmationDialog(
            "Delete \"\(deleteTarget?.displayName ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Video & Moves", role: .destructive) {
                if let v = deleteTarget { deleteVideo(v) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Videos", systemImage: "film.stack")
        } description: {
            Text("Tap + to import a practice video from Photos.")
        }
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

    private func deleteVideo(_ video: Video) {
        let videoID = video.id
        Task { await ThumbnailService.shared.clearCache(for: videoID) }
        try? FileManager.default.removeItem(at: video.fileURL)
        modelContext.delete(video)
        Haptics.medium()
    }

    // MARK: - Export

    @MainActor
    private func runExport() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            try modelContext.save()  // flush pending edits so the export is consistent
            let exporter = LibraryExporter(modelContainer: modelContext.container)
            let result = try await exporter.export()
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
        return "CumbiaMoves-Library-\(df.string(from: Date()))"
    }
}

// MARK: - Export summary sheet

private struct ExportSummarySheet: View {
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
