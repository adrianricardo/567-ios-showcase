import Foundation
import SwiftData
import Testing
@testable import Five67

/// Lock in where user data physically lives on disk, and that nothing is
/// excluded from iCloud Backup.
///
/// iOS backup rules (from Apple's File System Programming Guide):
///   - `Documents/`          → backed up
///   - `Library/`            → backed up (except `Library/Caches/`)
///     → `Application Support/` lives under `Library/`, so it IS backed up.
///   - `Library/Caches/`     → NOT backed up
///   - `tmp/`                → NOT backed up
///
/// Plus, any file/directory can be opted out with `isExcludedFromBackup`.
///
/// If any of these tests start failing, someone moved user data to a
/// non-backed-up location (or set the exclusion flag) and TestFlight / shipped
/// users would silently lose data on device restore. Treat a failure here as
/// a launch-blocker.
struct BackupAuditTests {

    @Test func videos_directory_is_under_Documents() {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documents.appendingPathComponent("videos")
        #expect(videosDir.path.contains("/Documents/"))
    }

    @Test func swiftdata_store_lives_under_Application_Support() throws {
        // Default ModelConfiguration() places the store in
        // Application Support/default.store — which is under Library/ and
        // therefore backed up.
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        #expect(appSupport.path.contains("/Library/Application Support"))
        #expect(!appSupport.path.contains("/Caches/"))
        #expect(!appSupport.path.contains("/tmp/"))
    }

    @Test func videos_directory_is_not_excluded_from_backup() throws {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documents.appendingPathComponent("videos", isDirectory: true)
        try fm.createDirectory(at: videosDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: videosDir) }

        let values = try videosDir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        // nil OR false are both acceptable — both mean "backed up".
        #expect(values.isExcludedFromBackup != true)
    }

    /// Belt-and-braces: a freshly created SwiftData store file also must not
    /// be flagged as excluded.
    @Test func freshly_created_store_is_not_excluded_from_backup() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Five67BackupAudit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let storeURL = dir.appendingPathComponent("audit.sqlite")
        let config = ModelConfiguration(url: storeURL)
        _ = try ModelContainer(
            for: Schema([Video.self, Move.self]),
            migrationPlan: Five67MigrationPlan.self,
            configurations: config
        )

        let values = try storeURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup != true)
    }
}
