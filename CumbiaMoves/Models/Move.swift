import Foundation
import SwiftData

@Model final class Move {
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

extension Move {
    var durationSeconds: TimeInterval? {
        guard let end = endTime else { return nil }
        return max(0, end - time)
    }

    var rangeLabel: String {
        if let end = endTime {
            let dur = String(format: "%.1f", max(0, end - time))
            return "\(formatTime(time)) → \(formatTime(end)) · \(dur)s"
        }
        return formatTime(time)
    }

    var isNamed: Bool { !name.isEmpty && !isExcluded }
}

func formatTime(_ seconds: TimeInterval) -> String {
    let t = max(0, seconds)
    let m = Int(t) / 60
    let s = t.truncatingRemainder(dividingBy: 60)
    return String(format: "%d:%04.1f", m, s)
}
