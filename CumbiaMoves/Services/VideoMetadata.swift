import AVFoundation
import Foundation

enum VideoMetadata {
    static func recordedDate(at url: URL) async -> Date? {
        let asset = AVURLAsset(url: url)

        if let creationItem = try? await asset.load(.creationDate),
           let date = try? await creationItem.load(.dateValue) {
            return date
        }

        if let common = try? await asset.load(.commonMetadata) {
            for item in common where item.commonKey == .commonKeyCreationDate {
                if let date = try? await item.load(.dateValue) { return date }
                if let str = try? await item.load(.stringValue),
                   let parsed = parseISO(str) {
                    return parsed
                }
            }
        }

        return nil
    }

    private static func parseISO(_ str: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: str)
    }
}
