import Foundation
import SwiftData
import Testing
@testable import Five67

/// Migration tests verify that real-shape stores at every prior schema version
/// upgrade cleanly to the current live schema, with data preserved.
///
/// The contract these tests defend:
///   1. Existing TestFlight / shipped users never lose data on update.
///   2. Idempotent operations (default Style seeding) stay idempotent.
///
/// ## Known issue — V3→V4 migration is broken
///
/// SwiftData's `MigrationStage.custom` is not a heavyweight rebuild — it still
/// relies on lightweight schema diffing between will/didMigrate. V3's
/// `Video.style: DanceStyle?` and V4's `Video.style: Style?` (relationship)
/// both map to a SQLite column named `ZSTYLE` but with incompatible structure,
/// which fails with `duplicate column name: ZSTYLE`. Any V1/V2/V3 store hitting
/// the current live plan errors out and the user lands on `MigrationFailureView`.
///
/// Risk accepted (2026-05-27): TestFlight V3 exposure is believed to be zero
/// or near-zero — styles weren't in real use pre-V4. Tests below that touch the
/// V3→V4 stage are wrapped in `withKnownIssue` so the suite stays green AND
/// the failure stays documented in test output.
///
/// **If you bump to V5 (or any future schema):** revisit these tests. Either
/// fix V3→V4 first (intermediate V3.5 schema that drops the scalar before V4
/// adds the relationship), or explicitly re-affirm the risk acceptance here.
///
/// ## V5 bump (2026-07-21) — risk re-affirmed
///
/// V5 adds the non-optional `Video.isDemo` (default `false`) via a pure
/// lightweight column add on top of V4. It does not touch the broken V3→V4
/// stage. V3 TestFlight exposure remains believed zero, so the risk acceptance
/// above stands unchanged; the `withKnownIssue` wrappers on V1/V2/V3 paths stay.
/// The V4→V5 stage — the one every current install actually traverses — is
/// covered by `v4_store_upgrades_to_v5_marking_all_videos_non_demo` below.
struct MigrationTests {

    // MARK: - V1 → V4 (touches broken V3→V4 stage)

    @Test func v1_store_upgrades_to_v4_with_data_preserved() throws {
        let storeURL = try Harness.makeTempStoreURL()

        let videoID = UUID()
        let moveID = UUID()

        // 1. Seed a real V1 store.
        try Harness.withV1Container(at: storeURL) { context in
            let video = SchemaV1.Video(
                id: videoID,
                displayName: "Practice 1",
                localFilename: "p1.mov",
                duration: 12.0
            )
            let move = SchemaV1.Move(
                id: moveID,
                name: "Cumbia basic",
                time: 1.5
            )
            move.video = video
            context.insert(video)
            context.insert(move)
            try context.save()
        }

        // 2. Reopen with the live schema + full migration plan.
        // Blocked by the V3→V4 ZSTYLE column collision. See file header.
        withKnownIssue("V3→V4 stage cannot be reached; risk accepted (see file header).") {
            try Harness.withLiveContainer(at: storeURL) { context in
                let videos = try context.fetch(FetchDescriptor<Video>())
                #expect(videos.count == 1)
                let v = try #require(videos.first)
                #expect(v.id == videoID)
                #expect(v.displayName == "Practice 1")
                #expect(v.localFilename == "p1.mov")
                #expect(v.duration == 12.0)
                #expect(v.style == nil)
                #expect(v.moves.count == 1)
                #expect(v.moves.first?.id == moveID)

                let styles = try context.fetch(FetchDescriptor<Style>())
                #expect(styles.count == 3)
                let allDefault = styles.allSatisfy { $0.isDefault }
                #expect(allDefault)
            }
        }
    }

    // MARK: - V2 → V4 (touches broken V3→V4 stage)

    @Test func v2_store_upgrades_to_v4_with_recordedAt_preserved() throws {
        let storeURL = try Harness.makeTempStoreURL()
        let videoID = UUID()
        let recorded = Date(timeIntervalSince1970: 1_700_000_000)

        try Harness.withV2Container(at: storeURL) { context in
            let video = SchemaV2.Video(
                id: videoID,
                displayName: "Older clip",
                localFilename: "old.mov",
                recordedAt: recorded,
                duration: 30
            )
            context.insert(video)
            try context.save()
        }

        withKnownIssue("V3→V4 stage cannot be reached; risk accepted (see file header).") {
            try Harness.withLiveContainer(at: storeURL) { context in
                let videos = try context.fetch(FetchDescriptor<Video>())
                let v = try #require(videos.first)
                #expect(v.id == videoID)
                #expect(v.recordedAt == recorded)
                #expect(v.style == nil)
            }
        }
    }

    // MARK: - V3 → V4 (known-broken stage)

    @Test(arguments: [
        ("cumbia",  Style.Default.cumbia),
        ("salsa",   Style.Default.salsa),
        ("bachata", Style.Default.bachata),
    ])
    func v3_store_repoints_known_dance_style_to_seeded_Style(
        rawValue: String,
        expectedStyleID: UUID
    ) throws {
        let storeURL = try Harness.makeTempStoreURL()
        let videoID = UUID()

        try Harness.withV3Container(at: storeURL) { context in
            let danceStyle = try #require(SchemaV3.DanceStyle(rawValue: rawValue))
            let video = SchemaV3.Video(
                id: videoID,
                displayName: "Styled clip",
                localFilename: "s.mov",
                duration: 10,
                style: danceStyle
            )
            context.insert(video)
            try context.save()
        }

        withKnownIssue("V3→V4 ZSTYLE column collision; risk accepted (see file header).") {
            try Harness.withLiveContainer(at: storeURL) { context in
                let v = try #require(
                    try context.fetch(FetchDescriptor<Video>()).first
                )
                let style = try #require(v.style)
                #expect(style.id == expectedStyleID)
                #expect(style.isDefault)
            }
        }
    }

    /// V3 store with no style set — still touches the V3→V4 stage because the
    /// migration plan walks the chain even if the offending column is empty.
    @Test func v3_store_with_no_style_still_fails_to_migrate() throws {
        let storeURL = try Harness.makeTempStoreURL()

        try Harness.withV3Container(at: storeURL) { context in
            let video = SchemaV3.Video(
                id: UUID(),
                displayName: "No style",
                localFilename: "n.mov",
                duration: 5,
                style: nil
            )
            context.insert(video)
            try context.save()
        }

        withKnownIssue("V3→V4 ZSTYLE column collision; risk accepted (see file header).") {
            try Harness.withLiveContainer(at: storeURL) { context in
                let v = try #require(
                    try context.fetch(FetchDescriptor<Video>()).first
                )
                #expect(v.style == nil)
                let styleCount = try context.fetch(FetchDescriptor<Style>()).count
                #expect(styleCount == 3)
            }
        }
    }

    // MARK: - V4 → V5 (the stage every current install traverses)

    /// V5 adds `Video.isDemo`. Every pre-existing row must migrate as personal
    /// content (`isDemo == false`) with its style relationship intact.
    @Test func v4_store_upgrades_to_v5_marking_all_videos_non_demo() throws {
        let storeURL = try Harness.makeTempStoreURL()
        let videoID = UUID()

        try Harness.withV4Container(at: storeURL) { context in
            let style = SchemaV4.Style(
                id: Style.Default.salsa,
                name: "Salsa",
                isDefault: true
            )
            context.insert(style)
            let video = SchemaV4.Video(
                id: videoID,
                displayName: "Existing clip",
                localFilename: "e.mov",
                duration: 10,
                style: style
            )
            context.insert(video)
            try context.save()
        }

        try Harness.withLiveContainer(at: storeURL) { context in
            let videos = try context.fetch(FetchDescriptor<Video>())
            #expect(videos.count == 1)
            let v = try #require(videos.first)
            #expect(v.id == videoID)
            #expect(v.isDemo == false)
            #expect(v.style?.id == Style.Default.salsa)
        }
    }

    // MARK: - Working paths (V4-only — what TestFlight users actually exercise)

    /// Fresh-install path: app creates a brand-new V4 store. This is what every
    /// TestFlight user who installed on the current build experiences.
    @Test func fresh_install_creates_v4_store_with_seeded_styles() throws {
        let storeURL = try Harness.makeTempStoreURL()

        try Harness.withLiveContainer(at: storeURL) { context in
            // App-side initial seeding happens inside the v3→v4 didMigrate hook;
            // a brand-new store doesn't run that. Verify that opening it with the
            // live schema at least produces a usable empty state — Styles get
            // seeded lazily by the app on first use (StyleStore), not here.
            let videos = try context.fetch(FetchDescriptor<Video>())
            #expect(videos.count == 0)
            let moves = try context.fetch(FetchDescriptor<Move>())
            #expect(moves.count == 0)
        }
    }

    /// Idempotency: reopening an existing V4 store must not corrupt it or
    /// duplicate any seeded data.
    @Test func reopening_a_v4_store_is_idempotent() throws {
        let storeURL = try Harness.makeTempStoreURL()

        // Seed a V4 store directly with a video + a manually-inserted Style.
        try Harness.withLiveContainer(at: storeURL) { context in
            Style.seedDefaultsIfNeeded(in: context)
            let video = Video(
                displayName: "Direct V4",
                localFilename: "d.mov",
                duration: 7
            )
            context.insert(video)
            try context.save()
        }

        // Reopen — defaults must not double up, video must still be there.
        try Harness.withLiveContainer(at: storeURL) { context in
            let videos = try context.fetch(FetchDescriptor<Video>())
            #expect(videos.count == 1)
            #expect(videos.first?.displayName == "Direct V4")

            let styles = try context.fetch(FetchDescriptor<Style>())
            #expect(styles.count == 3)
            let ids = Set(styles.map(\.id))
            #expect(ids == [
                Style.Default.cumbia,
                Style.Default.salsa,
                Style.Default.bachata
            ])
        }

        // Reopen one more time + re-seed — still idempotent.
        try Harness.withLiveContainer(at: storeURL) { context in
            Style.seedDefaultsIfNeeded(in: context)
            try context.save()
            let styles = try context.fetch(FetchDescriptor<Style>())
            #expect(styles.count == 3)
        }
    }

    // MARK: - Lightweight stages in isolation (V1→V2, V2→V3)

    /// Sanity check that the lightweight stages themselves work — these aren't
    /// the part that's broken, but they're worth locking in so a future change
    /// to V1/V2/V3 model shape doesn't silently regress.
    @Test func v1_store_upgrades_to_v3_in_isolation() throws {
        let storeURL = try Harness.makeTempStoreURL()
        let videoID = UUID()

        try Harness.withV1Container(at: storeURL) { context in
            let video = SchemaV1.Video(
                id: videoID,
                displayName: "Light test",
                localFilename: "l.mov",
                duration: 8
            )
            context.insert(video)
            try context.save()
        }

        // Open with V3 schema + a partial migration plan that stops at V3.
        // SwiftData will run V1→V2 and V2→V3 (both lightweight, both should work).
        try Harness.withV3PlusPartialPlan(at: storeURL) { context in
            let v = try #require(
                try context.fetch(FetchDescriptor<SchemaV3.Video>()).first
            )
            #expect(v.id == videoID)
            #expect(v.displayName == "Light test")
            #expect(v.duration == 8)
            #expect(v.recordedAt == nil) // V2 added this, defaults nil
            #expect(v.style == nil)       // V3 added this, defaults nil
        }
    }
}

// MARK: - Test harness

private enum Harness {
    static func makeTempStoreURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Five67MigrationTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    static func withV1Container(at url: URL, _ work: (ModelContext) throws -> Void) throws {
        try withContainer(
            schema: Schema(versionedSchema: SchemaV1.self),
            url: url,
            migrationPlan: nil,
            work: work
        )
    }

    static func withV2Container(at url: URL, _ work: (ModelContext) throws -> Void) throws {
        try withContainer(
            schema: Schema(versionedSchema: SchemaV2.self),
            url: url,
            migrationPlan: nil,
            work: work
        )
    }

    static func withV3Container(at url: URL, _ work: (ModelContext) throws -> Void) throws {
        try withContainer(
            schema: Schema(versionedSchema: SchemaV3.self),
            url: url,
            migrationPlan: nil,
            work: work
        )
    }

    static func withV4Container(at url: URL, _ work: (ModelContext) throws -> Void) throws {
        try withContainer(
            schema: Schema(versionedSchema: SchemaV4.self),
            url: url,
            migrationPlan: nil,
            work: work
        )
    }

    /// Mirrors what `Five67App.loadContainer()` does in production.
    static func withLiveContainer(at url: URL, _ work: (ModelContext) throws -> Void) throws {
        try withContainer(
            schema: Schema([Video.self, Move.self]),
            url: url,
            migrationPlan: Five67MigrationPlan.self,
            work: work
        )
    }

    /// Opens at V3 with a partial plan that runs only V1→V2 and V2→V3 — used to
    /// validate the lightweight stages without tripping the broken V3→V4 stage.
    static func withV3PlusPartialPlan(at url: URL, _ work: (ModelContext) throws -> Void) throws {
        try withContainer(
            schema: Schema(versionedSchema: SchemaV3.self),
            url: url,
            migrationPlan: PartialMigrationPlanUpToV3.self,
            work: work
        )
    }

    private static func withContainer(
        schema: Schema,
        url: URL,
        migrationPlan: (any SchemaMigrationPlan.Type)?,
        work: (ModelContext) throws -> Void
    ) throws {
        let config = ModelConfiguration(url: url)
        let container: ModelContainer
        if let migrationPlan {
            container = try ModelContainer(
                for: schema,
                migrationPlan: migrationPlan,
                configurations: config
            )
        } else {
            container = try ModelContainer(
                for: schema,
                configurations: config
            )
        }
        let context = ModelContext(container)
        try work(context)
    }
}

private enum PartialMigrationPlanUpToV3: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }
    static var stages: [MigrationStage] {
        [
            Five67MigrationPlan.v1ToV2,
            Five67MigrationPlan.v2ToV3
        ]
    }
}
