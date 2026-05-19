import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MigrationFailureView: View {
    let error: Error
    let onReset: () -> Void

    @State private var showResetConfirm = false
    @State private var showExporter = false
    @State private var exportError: String?
    @State private var exportDocument: RawStoreExportDocument?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                errorDetails
                actions
                Spacer(minLength: 16)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .confirmationDialog(
            "Reset library?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset and lose all data", role: .destructive, action: onReset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your library database. Imported video files in Documents/videos will remain on disk but will no longer be referenced. This cannot be undone.")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .folder,
            defaultFilename: defaultExportFolderName()
        ) { result in
            switch result {
            case .success:
                exportError = nil
            case .failure(let err):
                exportError = err.localizedDescription
            }
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Couldn't open your library")
                .font(.title.bold())
            Text("We couldn't load your saved videos and moves. Your files are still on the device — please export them before resetting.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var errorDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Error details")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(describing: error))
                .font(.footnote.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .textSelection(.enabled)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                presentExporter()
            } label: {
                Label("Export current data", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                openSupportMail()
            } label: {
                Label("Contact support", systemImage: "envelope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset library", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Export

    private func presentExporter() {
        do {
            let bundle = try RawStoreExport.buildBundle()
            exportDocument = RawStoreExportDocument(bundleURL: bundle)
            showExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func defaultExportFolderName() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmm"
        return "CumbiaMoves-Recovery-\(df.string(from: Date()))"
    }

    // MARK: - Support mail

    private func openSupportMail() {
        let subject = "Cumbia Moves: library load failure"
        let body = """
        App could not open the library database.

        Error:
        \(String(describing: error))
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "567@agentmail.to"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Raw store export

enum RawStoreExport {
    /// Copies the SwiftData store files and the Documents/videos directory into a temporary
    /// folder structure suitable for export via fileExporter(.folder).
    static func buildBundle() throws -> URL {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory
            .appendingPathComponent("CumbiaMovesRecovery-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        // 1. SwiftData store files from Application Support.
        let supportDir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let storeDir = tempRoot.appendingPathComponent("store", isDirectory: true)
        try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
        for suffix in ["", "-shm", "-wal"] {
            let src = supportDir.appendingPathComponent("default.store\(suffix)")
            if fm.fileExists(atPath: src.path) {
                let dst = storeDir.appendingPathComponent("default.store\(suffix)")
                try? fm.copyItem(at: src, to: dst)
            }
        }

        // 2. Imported video files from Documents/videos.
        let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosSrc = documentsDir.appendingPathComponent("videos", isDirectory: true)
        if fm.fileExists(atPath: videosSrc.path) {
            let videosDst = tempRoot.appendingPathComponent("videos", isDirectory: true)
            try? fm.copyItem(at: videosSrc, to: videosDst)
        }

        // 3. README explaining the bundle.
        let readme = """
        Cumbia Moves recovery bundle

        - store/default.store(-shm|-wal)?  : Raw SwiftData (SQLite) library database.
        - videos/                          : Imported video files (.mov).

        Keep this folder safe. If you contact support, attach a zipped copy.
        """
        try? readme.data(using: .utf8)?.write(
            to: tempRoot.appendingPathComponent("README.txt")
        )

        return tempRoot
    }
}

struct RawStoreExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    static var writableContentTypes: [UTType] { [.folder] }

    let bundleURL: URL

    init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: bundleURL, options: [.immediate])
    }
}
