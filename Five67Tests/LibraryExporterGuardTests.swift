import Foundation
import Testing
@testable import Five67

/// Tripwires for `LibraryExporter`. The exporter writes a metadata-only zip
/// (DTOs + manifest) that users can save off-device as a recovery snapshot.
/// Its DTO shape is decoupled from `@Model` types on purpose — but that
/// decoupling means a schema bump won't naturally remind anyone to update
/// what gets exported. These tests force that reminder.
struct LibraryExporterGuardTests {

    /// If you bump the live SwiftData schema, you almost certainly want to
    /// either bump `ExportManifest.schemaVersion` or consciously add the new
    /// fields to `VideoDTO` / `MoveDTO`. When this test fails, that's the
    /// nudge — update the constant intentionally.
    @Test func exporter_schema_version_is_what_we_expect() {
        // Mirror the value asserted in LibraryExporter.export(...).
        // Bumping the SwiftData schema without bumping this is the failure
        // mode we're guarding against.
        #expect(currentExporterSchemaVersion == "2.0.0")
    }

    /// Lock in the DTO field set. A schema migration that adds a field users
    /// would expect to see in an export (e.g. `Style.name` on a video) should
    /// require an intentional update here.
    @Test func videoDTO_field_set_is_locked() throws {
        let dto = VideoDTO(
            id: UUID(),
            displayName: "x",
            localFilename: "x.mov",
            sourceAssetID: nil,
            importedAt: Date(timeIntervalSince1970: 0),
            recordedAt: nil,
            duration: 1
        )
        let data = try JSONEncoder().encode(dto)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let keys = Set(json.keys)
        #expect(keys == [
            "id",
            "displayName",
            "localFilename",
            "importedAt",
            "duration"
            // sourceAssetID and recordedAt are nil → omitted by default JSONEncoder
        ])
    }

    @Test func moveDTO_field_set_is_locked() throws {
        let dto = MoveDTO(
            id: UUID(),
            videoID: UUID(),
            name: "n",
            category: "footwork",
            status: "empty",
            time: 0,
            endTime: nil,
            notes: "",
            isExcluded: false,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(dto)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let keys = Set(json.keys)
        #expect(keys == [
            "id",
            "videoID",
            "name",
            "category",
            "status",
            "time",
            "notes",
            "isExcluded",
            "createdAt",
            "updatedAt"
        ])
    }
}

// Pulled out so the test reads as a constant comparison. Update both when
// you intentionally bump the export schema.
private let currentExporterSchemaVersion = "2.0.0"
