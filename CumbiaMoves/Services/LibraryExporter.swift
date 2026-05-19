import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Result types

struct LibraryExportResult: Sendable {
    let zipURL: URL
    let videoCount: Int
    let moveCount: Int
    let missingFiles: [String]
    let orphanFiles: [String]
    let orphanMoveCount: Int
    let exportedAt: Date

    var hasIntegrityIssues: Bool {
        !missingFiles.isEmpty || !orphanFiles.isEmpty || orphanMoveCount > 0
    }
}

enum LibraryExportError: LocalizedError {
    case zipFailed(String)
    case fileCoordinationFailed(String)

    var errorDescription: String? {
        switch self {
        case .zipFailed(let msg):              return "Couldn't build export archive: \(msg)"
        case .fileCoordinationFailed(let msg): return "File coordinator failed: \(msg)"
        }
    }
}

// MARK: - DTOs (decoupled from @Model so schema changes don't break exports)

struct VideoDTO: Codable {
    let id: UUID
    let displayName: String
    let localFilename: String
    let sourceAssetID: String?
    let importedAt: Date
    let recordedAt: Date?
    let duration: TimeInterval
}

struct MoveDTO: Codable {
    let id: UUID
    let videoID: UUID?
    let name: String
    let category: String
    let status: String
    let time: TimeInterval
    let endTime: TimeInterval?
    let notes: String
    let isExcluded: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct LibraryArchive: Codable {
    let videos: [VideoDTO]
    let moves: [MoveDTO]
}

struct IntegrityReport: Codable {
    let missingFiles: [String]
    let orphanFiles: [String]
    let orphanMoveCount: Int
}

struct ExportManifest: Codable {
    let appVersion: String
    let appBuild: String
    let exportedAt: Date
    let schemaVersion: String
    let videoCount: Int
    let moveCount: Int
    let integrity: IntegrityReport
}

// MARK: - Exporter

@ModelActor
actor LibraryExporter {

    func export() async throws -> LibraryExportResult {
        let videos = try modelContext.fetch(FetchDescriptor<Video>())
        let moves = try modelContext.fetch(FetchDescriptor<Move>())

        let fm = FileManager.default
        let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsDir.appendingPathComponent("videos", isDirectory: true)

        // 1. Build DTOs.
        let videoDTOs = videos.map { v in
            VideoDTO(
                id: v.id,
                displayName: v.displayName,
                localFilename: v.localFilename,
                sourceAssetID: v.sourceAssetID,
                importedAt: v.importedAt,
                recordedAt: v.recordedAt,
                duration: v.duration
            )
        }
        let moveDTOs = moves.map { m in
            MoveDTO(
                id: m.id,
                videoID: m.video?.id,
                name: m.name,
                category: m.category.rawValue,
                status: m.status.rawValue,
                time: m.time,
                endTime: m.endTime,
                notes: m.notes,
                isExcluded: m.isExcluded,
                createdAt: m.createdAt,
                updatedAt: m.updatedAt
            )
        }

        // 2. Integrity report.
        let referencedFilenames = Set(videoDTOs.map(\.localFilename))
        let onDiskFilenames: Set<String>
        if fm.fileExists(atPath: videosDir.path) {
            let contents = (try? fm.contentsOfDirectory(
                at: videosDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )) ?? []
            onDiskFilenames = Set(contents.map { $0.lastPathComponent })
        } else {
            onDiskFilenames = []
        }

        let missingFiles = videoDTOs
            .filter { !onDiskFilenames.contains($0.localFilename) }
            .map { $0.localFilename }
            .sorted()
        let orphanFiles = onDiskFilenames
            .subtracting(referencedFilenames)
            .sorted()
        let orphanMoveCount = moveDTOs.filter { $0.videoID == nil }.count

        let integrity = IntegrityReport(
            missingFiles: missingFiles,
            orphanFiles: orphanFiles,
            orphanMoveCount: orphanMoveCount
        )

        // 3. Manifest.
        let manifest = ExportManifest(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
            exportedAt: Date(),
            schemaVersion: "2.0.0",
            videoCount: videoDTOs.count,
            moveCount: moveDTOs.count,
            integrity: integrity
        )

        // 4. Stage everything in a temp directory.
        let stageRoot = fm.temporaryDirectory
            .appendingPathComponent("CumbiaMovesExport-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stageRoot, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let library = LibraryArchive(videos: videoDTOs, moves: moveDTOs)
        try encoder.encode(library).write(to: stageRoot.appendingPathComponent("library.json"))
        try encoder.encode(manifest).write(to: stageRoot.appendingPathComponent("manifest.json"))

        // Copy videos (only the ones that actually exist on disk).
        let videosStageDir = stageRoot.appendingPathComponent("videos", isDirectory: true)
        try fm.createDirectory(at: videosStageDir, withIntermediateDirectories: true)
        for dto in videoDTOs {
            let src = videosDir.appendingPathComponent(dto.localFilename)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = videosStageDir.appendingPathComponent(dto.localFilename)
            try fm.copyItem(at: src, to: dst)
        }

        // 5. Zip via NSFileCoordinator(.forUploading). This is the documented technique
        // for producing a zip representation of a directory; works back to iOS 8.
        let zipURL = try zipDirectory(at: stageRoot, suggestedName: "CumbiaMoves-Library")

        // Clean up the stage dir; the zip lives on its own.
        try? fm.removeItem(at: stageRoot)

        return LibraryExportResult(
            zipURL: zipURL,
            videoCount: videoDTOs.count,
            moveCount: moveDTOs.count,
            missingFiles: missingFiles,
            orphanFiles: orphanFiles,
            orphanMoveCount: orphanMoveCount,
            exportedAt: manifest.exportedAt
        )
    }

    private nonisolated func zipDirectory(at dir: URL, suggestedName: String) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var zipResult: Result<URL, Error>?

        let semaphore = DispatchSemaphore(value: 0)

        coordinator.coordinate(
            readingItemAt: dir,
            options: [.forUploading],
            error: &coordError
        ) { zippedURL in
            // `zippedURL` is a temp .zip created by the coordinator. It only lives
            // for the duration of this callback, so we have to copy it out now.
            let dst = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(suggestedName).zip")
            try? FileManager.default.removeItem(at: dst)
            do {
                try FileManager.default.copyItem(at: zippedURL, to: dst)
                zipResult = .success(dst)
            } catch {
                zipResult = .failure(error)
            }
            semaphore.signal()
        }

        if let coordError {
            throw LibraryExportError.fileCoordinationFailed(coordError.localizedDescription)
        }

        // The coordinate(...) block is synchronous on the calling thread for local
        // file URLs, but signal/wait for belt-and-braces.
        _ = semaphore.wait(timeout: .now() + 60)

        switch zipResult {
        case .success(let url): return url
        case .failure(let err): throw LibraryExportError.zipFailed(err.localizedDescription)
        case .none:             throw LibraryExportError.zipFailed("No result produced by file coordinator")
        }
    }
}

// MARK: - FileDocument wrapper for fileExporter

struct LibraryExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    static var writableContentTypes: [UTType] { [.zip] }

    let zipURL: URL

    init(zipURL: URL) {
        self.zipURL = zipURL
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: zipURL, options: [.immediate])
    }
}
