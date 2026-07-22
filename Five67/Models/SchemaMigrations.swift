import Foundation
import SwiftData

// MARK: - V1 (pre-recordedAt)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Video.self, Move.self]
    }

    @Model
    final class Video {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var localFilename: String
        var sourceAssetID: String?
        var importedAt: Date
        var duration: TimeInterval
        @Relationship(deleteRule: .cascade) var moves: [Move] = []

        init(
            id: UUID = UUID(),
            displayName: String,
            localFilename: String,
            sourceAssetID: String? = nil,
            importedAt: Date = Date(),
            duration: TimeInterval
        ) {
            self.id = id
            self.displayName = displayName
            self.localFilename = localFilename
            self.sourceAssetID = sourceAssetID
            self.importedAt = importedAt
            self.duration = duration
        }
    }

    @Model
    final class Move {
        @Attribute(.unique) var id: UUID
        var name: String
        var category: Category
        var status: Status
        var time: TimeInterval
        var endTime: TimeInterval?
        var notes: String
        var isExcluded: Bool
        var createdAt: Date
        var updatedAt: Date
        var video: Video?

        init(
            id: UUID = UUID(),
            name: String,
            category: Category = .footwork,
            status: Status = .empty,
            time: TimeInterval,
            endTime: TimeInterval? = nil,
            notes: String = "",
            isExcluded: Bool = false,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            video: Video? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.status = status
            self.time = time
            self.endTime = endTime
            self.notes = notes
            self.isExcluded = isExcluded
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.video = video
        }
    }
}

// MARK: - V2 (adds Video.recordedAt)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Video.self, Move.self]
    }

    @Model
    final class Video {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var localFilename: String
        var sourceAssetID: String?
        var importedAt: Date
        var recordedAt: Date?
        var duration: TimeInterval
        @Relationship(deleteRule: .cascade) var moves: [Move] = []

        init(
            id: UUID = UUID(),
            displayName: String,
            localFilename: String,
            sourceAssetID: String? = nil,
            importedAt: Date = Date(),
            recordedAt: Date? = nil,
            duration: TimeInterval
        ) {
            self.id = id
            self.displayName = displayName
            self.localFilename = localFilename
            self.sourceAssetID = sourceAssetID
            self.importedAt = importedAt
            self.recordedAt = recordedAt
            self.duration = duration
        }
    }

    @Model
    final class Move {
        @Attribute(.unique) var id: UUID
        var name: String
        var category: Category
        var status: Status
        var time: TimeInterval
        var endTime: TimeInterval?
        var notes: String
        var isExcluded: Bool
        var createdAt: Date
        var updatedAt: Date
        var video: Video?

        init(
            id: UUID = UUID(),
            name: String,
            category: Category = .footwork,
            status: Status = .empty,
            time: TimeInterval,
            endTime: TimeInterval? = nil,
            notes: String = "",
            isExcluded: Bool = false,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            video: Video? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.status = status
            self.time = time
            self.endTime = endTime
            self.notes = notes
            self.isExcluded = isExcluded
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.video = video
        }
    }
}

// MARK: - V3 (adds Video.style: DanceStyle? scalar)
//
// Inlined so the live `Video` type can move forward to V4 without changing
// what V3 means on disk. The V4 migration reads from these V3 types.

enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Video.self, Move.self]
    }

    enum DanceStyle: String, Codable {
        case cumbia, salsa, bachata
    }

    @Model
    final class Video {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var localFilename: String
        var sourceAssetID: String?
        var importedAt: Date
        var recordedAt: Date?
        var duration: TimeInterval
        var style: DanceStyle?
        @Relationship(deleteRule: .cascade) var moves: [Move] = []

        init(
            id: UUID = UUID(),
            displayName: String,
            localFilename: String,
            sourceAssetID: String? = nil,
            importedAt: Date = Date(),
            recordedAt: Date? = nil,
            duration: TimeInterval,
            style: DanceStyle? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.localFilename = localFilename
            self.sourceAssetID = sourceAssetID
            self.importedAt = importedAt
            self.recordedAt = recordedAt
            self.duration = duration
            self.style = style
        }
    }

    @Model
    final class Move {
        @Attribute(.unique) var id: UUID
        var name: String
        var category: Category
        var status: Status
        var time: TimeInterval
        var endTime: TimeInterval?
        var notes: String
        var isExcluded: Bool
        var createdAt: Date
        var updatedAt: Date
        var video: Video?

        init(
            id: UUID = UUID(),
            name: String,
            category: Category = .footwork,
            status: Status = .empty,
            time: TimeInterval,
            endTime: TimeInterval? = nil,
            notes: String = "",
            isExcluded: Bool = false,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            video: Video? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.status = status
            self.time = time
            self.endTime = endTime
            self.notes = notes
            self.isExcluded = isExcluded
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.video = video
        }
    }
}

// MARK: - V4 (DanceStyle scalar → Style @Model relationship)
//
// Inlined as a frozen snapshot so the live `Video`/`Style`/`Move` types can move
// forward to V5 (adds `Video.isDemo`) without changing what V4 means on disk.

enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Video.self, Move.self, Style.self]
    }

    @Model
    final class Video {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var localFilename: String
        var sourceAssetID: String?
        var importedAt: Date
        var recordedAt: Date?
        var duration: TimeInterval
        var style: Style?
        @Relationship(deleteRule: .cascade) var moves: [Move] = []

        init(
            id: UUID = UUID(),
            displayName: String,
            localFilename: String,
            sourceAssetID: String? = nil,
            importedAt: Date = Date(),
            recordedAt: Date? = nil,
            duration: TimeInterval,
            style: Style? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.localFilename = localFilename
            self.sourceAssetID = sourceAssetID
            self.importedAt = importedAt
            self.recordedAt = recordedAt
            self.duration = duration
            self.style = style
        }
    }

    @Model
    final class Move {
        @Attribute(.unique) var id: UUID
        var name: String
        var category: Category
        var status: Status
        var time: TimeInterval
        var endTime: TimeInterval?
        var notes: String
        var isExcluded: Bool
        var createdAt: Date
        var updatedAt: Date
        var video: Video?

        init(
            id: UUID = UUID(),
            name: String,
            category: Category = .footwork,
            status: Status = .empty,
            time: TimeInterval,
            endTime: TimeInterval? = nil,
            notes: String = "",
            isExcluded: Bool = false,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            video: Video? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.status = status
            self.time = time
            self.endTime = endTime
            self.notes = notes
            self.isExcluded = isExcluded
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.video = video
        }
    }

    @Model
    final class Style {
        @Attribute(.unique) var id: UUID
        var name: String
        var isDefault: Bool
        var createdAt: Date
        @Relationship(inverse: \Video.style) var videos: [Video] = []

        init(
            id: UUID = UUID(),
            name: String,
            isDefault: Bool = false,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.createdAt = createdAt
        }
    }
}

// MARK: - V5 (adds Video.isDemo) — current live schema

enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Video.self, Move.self, Style.self]
    }
}

// MARK: - Migration plan

enum Five67MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3, v3ToV4, v4ToV5]
    }

    /// V4→V5 adds the non-optional `Video.isDemo` (default `false`), so every
    /// existing row migrates as personal content. The default value makes this a
    /// pure lightweight column add.
    static let v4ToV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    /// Snapshot of `(videoID → V3 raw style)` captured in `willMigrate` and
    /// consumed in `didMigrate`. The two closures don't share a context, so we
    /// bridge through this static. Cleared after use. Marked `nonisolated(unsafe)`
    /// because migrations run on a private actor and SwiftData serializes the
    /// stages — there is no concurrent access.
    nonisolated(unsafe) static var v3StyleSnapshot: [UUID: String] = [:]

    static let v3ToV4 = MigrationStage.custom(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self,
        willMigrate: { context in
            let videos = try context.fetch(FetchDescriptor<SchemaV3.Video>())
            var map: [UUID: String] = [:]
            for v in videos {
                if let raw = v.style?.rawValue {
                    map[v.id] = raw
                }
            }
            v3StyleSnapshot = map
        },
        didMigrate: { context in
            // 1. Seed the three defaults at V4 shape (idempotent — safe on
            //    re-launch too). Pinned to `SchemaV4.Style` so this stage's
            //    destination shape stays fixed even after the live type advances.
            let defaultSpecs: [(UUID, String)] = [
                (Style.Default.cumbia, "Cumbia"),
                (Style.Default.salsa, "Salsa"),
                (Style.Default.bachata, "Bachata")
            ]
            for (id, name) in defaultSpecs {
                let descriptor = FetchDescriptor<SchemaV4.Style>(
                    predicate: #Predicate { $0.id == id }
                )
                if (try? context.fetch(descriptor).first) == nil {
                    context.insert(SchemaV4.Style(id: id, name: name, isDefault: true))
                }
            }

            // 2. Re-point every video whose V3 style we captured.
            let allStyles = try context.fetch(FetchDescriptor<SchemaV4.Style>())
            let stylesByID = Dictionary(uniqueKeysWithValues: allStyles.map { ($0.id, $0) })

            let videos = try context.fetch(FetchDescriptor<SchemaV4.Video>())
            for v in videos {
                guard
                    let raw = v3StyleSnapshot[v.id],
                    let seededID = Style.Default.id(forRawValue: raw),
                    let style = stylesByID[seededID]
                else { continue }
                v.style = style
            }

            try context.save()
            v3StyleSnapshot = [:]
        }
    )
}
