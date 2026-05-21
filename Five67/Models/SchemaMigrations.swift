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
}

// MARK: - Migration plan

enum Five67MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
