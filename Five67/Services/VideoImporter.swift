import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum ImportError: LocalizedError {
    case transferFailed
    case durationUnavailable
    case alreadyImported(UUID)
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .transferFailed:       return "Could not read the selected video."
        case .durationUnavailable:  return "Could not determine video duration."
        case .alreadyImported:      return "This video is already in your library."
        case .fileAccessDenied:     return "Could not access the selected file."
        }
    }
}

struct VideoImportResult {
    let filename: String
    let displayName: String
    let duration: TimeInterval
    let sourceID: String?
    let recordedAt: Date?
}

struct VideoImporter {
    static func `import`(
        from item: PhotosPickerItem,
        existingSourceIDs: [String: UUID]
    ) async throws -> VideoImportResult {
        guard let loaded = try? await item.loadTransferable(type: MovieTransferable.self) else {
            throw ImportError.transferFailed
        }

        let sourceID = item.itemIdentifier

        if let sourceID, let existingID = existingSourceIDs[sourceID] {
            throw ImportError.alreadyImported(existingID)
        }

        // Photos imports come through a temp file named with a UUID, so we don't
        // have a meaningful original name — let ingest synthesize one from the date.
        return try await ingest(
            sourceURL: loaded.url,
            originalName: nil,
            sourceID: sourceID
        )
    }

    /// Import from a file URL (e.g. Files picker, or the bundled demo asset).
    /// Caller is responsible for any security-scoped resource access around the URL.
    ///
    /// `sourceID` is normally nil for user file imports; the bundled demo passes a
    /// stable identifier so repeat ingestion can be deduped.
    static func `import`(
        fromFileURL url: URL,
        sourceID: String? = nil
    ) async throws -> VideoImportResult {
        return try await ingest(
            sourceURL: url,
            originalName: url.deletingPathExtension().lastPathComponent,
            sourceID: sourceID
        )
    }

    // MARK: - Shared ingestion

    private static func ingest(
        sourceURL: URL,
        originalName: String?,
        sourceID: String?
    ) async throws -> VideoImportResult {
        let asset = AVURLAsset(url: sourceURL)
        let duration: TimeInterval
        if let dur = try? await asset.load(.duration), dur.seconds.isFinite {
            duration = dur.seconds
        } else {
            throw ImportError.durationUnavailable
        }

        let recordedAt = await VideoMetadata.recordedDate(at: sourceURL)

        let videosDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("videos")
        try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let filename = uniqueDateBasedFilename(
            date: recordedAt ?? Date(),
            ext: fileExtension,
            in: videosDir
        )
        let dest = videosDir.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: dest)

        let displayName = displayName(
            from: originalName,
            recordedAt: recordedAt
        )

        return VideoImportResult(
            filename: filename,
            displayName: displayName,
            duration: duration,
            sourceID: sourceID,
            recordedAt: recordedAt
        )
    }

    private static func displayName(from originalName: String?, recordedAt: Date?) -> String {
        if let originalName, !looksLikeUUID(originalName) {
            return originalName.replacingOccurrences(of: "_", with: " ")
        }
        let date = recordedAt ?? Date()
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func looksLikeUUID(_ s: String) -> Bool {
        UUID(uuidString: s) != nil
    }

    private static func uniqueDateBasedFilename(date: Date, ext: String, in directory: URL) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        let base = df.string(from: date)

        var candidate = "\(base).\(ext)"
        var counter = 2
        let fm = FileManager.default
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(counter).\(ext)"
            counter += 1
        }
        return candidate
    }
}

// MARK: - Transferable wrapper

struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .video) { received in
            try copyReceivedFile(received)
        }
        FileRepresentation(importedContentType: .mpeg4Movie) { received in
            try copyReceivedFile(received)
        }
        FileRepresentation(importedContentType: .quickTimeMovie) { received in
            try copyReceivedFile(received)
        }
        FileRepresentation(importedContentType: .movie) { received in
            try copyReceivedFile(received)
        }
    }

    private static func copyReceivedFile(_ received: ReceivedTransferredFile) throws -> MovieTransferable {
        let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + fileExtension)
        try FileManager.default.copyItem(at: received.file, to: tmp)
        return MovieTransferable(url: tmp)
    }
}
