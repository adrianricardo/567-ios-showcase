import Foundation
import SwiftData

/// A dance style a video can be tagged with. Replaces the V3 `DanceStyle` enum
/// so users can rename / add their own styles. The three original cases
/// (Cumbia, Salsa, Bachata) are seeded as `isDefault = true` and are not
/// renameable / deletable from the UI.
@Model final class Style {
    @Attribute(.unique) var id: UUID
    var name: String
    /// True for the three seeded defaults. UI gates rename/delete on this.
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

extension Style {
    /// Stable UUIDs for the three seeded defaults. Idempotent across launches
    /// and across the V3→V4 migration: rerunning seed only inserts what's
    /// missing, never duplicates.
    enum Default {
        static let cumbia  = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        static let salsa   = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        static let bachata = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        /// Lookup: V3 raw value → seeded Style UUID. Used by the V3→V4
        /// migration to re-point the old scalar onto the new relationship.
        static func id(forRawValue raw: String) -> UUID? {
            switch raw {
            case "cumbia":  return cumbia
            case "salsa":   return salsa
            case "bachata": return bachata
            default:        return nil
            }
        }
    }

    /// Inserts any missing default Style rows. Safe to call on every launch.
    @discardableResult
    static func seedDefaultsIfNeeded(in context: ModelContext) -> [Style] {
        let specs: [(UUID, String)] = [
            (Default.cumbia,  "Cumbia"),
            (Default.salsa,   "Salsa"),
            (Default.bachata, "Bachata")
        ]
        var inserted: [Style] = []
        for (id, name) in specs {
            let descriptor = FetchDescriptor<Style>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try? context.fetch(descriptor).first {
                inserted.append(existing)
                continue
            }
            let style = Style(id: id, name: name, isDefault: true)
            context.insert(style)
            inserted.append(style)
        }
        return inserted
    }
}
