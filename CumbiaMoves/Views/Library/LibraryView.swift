import SwiftUI
import SwiftData
import Photos
import PhotosUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Video.importedAt, order: .reverse) private var videos: [Video]

    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showError = false
    @State private var deleteTarget: Video?
    @State private var showDeleteConfirm = false

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
                                Button(role: .destructive) {
                                    deleteTarget = video
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
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
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(
                        selection: $pickerItem,
                        matching: nil,
                        preferredItemEncoding: .current,
                        photoLibrary: .shared()
                    ) {
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
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await handleImport(item) }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred.")
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

    private func handleImport(_ item: PhotosPickerItem) async {
        isImporting = true
        pickerItem = nil
        defer { isImporting = false }

        do {
            let existingSourceIDs = Dictionary(uniqueKeysWithValues: videos.compactMap { v in
                v.sourceAssetID.map { ($0, v.id) }
            })
            let result = try await VideoImporter.import(from: item, existingSourceIDs: existingSourceIDs)
            let video = Video(
                displayName: result.displayName,
                localFilename: result.filename,
                sourceAssetID: result.sourceID,
                recordedAt: result.recordedAt,
                duration: result.duration
            )
            modelContext.insert(video)
            Haptics.success()

            // Pre-generate thumbnail strip in background
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
        } catch ImportError.alreadyImported(let existingID) {
            // Navigate to the existing video instead of showing error
            _ = existingID  // SwiftUI navigation could be triggered here
        } catch {
            importError = error.localizedDescription
            showError = true
        }
    }

    private func deleteVideo(_ video: Video) {
        let videoID = video.id
        Task { await ThumbnailService.shared.clearCache(for: videoID) }
        try? FileManager.default.removeItem(at: video.fileURL)
        modelContext.delete(video)
        Haptics.medium()
    }
}
