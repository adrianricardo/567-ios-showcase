import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum ImportError: LocalizedError {
    case transferFailed
    case durationUnavailable
    case alreadyImported(UUID)

    var errorDescription: String? {
        switch self {
        case .transferFailed:       return "Could not read the selected video."
        case .durationUnavailable:  return "Could not determine video duration."
        case .alreadyImported:      return "This video is already in your library."
        }
    }
}

struct VideoImporter {
    static func `import`(
        from item: PhotosPickerItem,
        existingSourceIDs: [String: UUID]
    ) async throws -> (filename: String, displayName: String, duration: TimeInterval, sourceID: String?, recordedAt: Date?) {
        guard let loaded = try? await item.loadTransferable(type: MovieTransferable.self) else {
            throw ImportError.transferFailed
        }

        let sourceID = item.itemIdentifier

        // Dedup check
        if let sourceID, let existingID = existingSourceIDs[sourceID] {
            throw ImportError.alreadyImported(existingID)
        }

        // Read duration
        let asset = AVURLAsset(url: loaded.url)
        let duration: TimeInterval
        if let dur = try? await asset.load(.duration), dur.seconds.isFinite {
            duration = dur.seconds
        } else {
            throw ImportError.durationUnavailable
        }

        let recordedAt = await VideoMetadata.recordedDate(at: loaded.url)

        // Copy to app sandbox
        let videosDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("videos")
        try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)

        let fileExtension = loaded.url.pathExtension.isEmpty ? "mov" : loaded.url.pathExtension
        let filename = UUID().uuidString + "." + fileExtension
        let dest = videosDir.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: loaded.url, to: dest)

        let displayName = loaded.url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")

        return (filename, displayName, duration, sourceID, recordedAt)
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
