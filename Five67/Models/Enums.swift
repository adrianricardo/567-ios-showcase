import SwiftUI

enum Category: String, Codable, CaseIterable, Identifiable {
    case turn, exit, basic, combo, footwork, other
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum Status: String, Codable, CaseIterable {
    case empty, stuck, mastered

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .empty:    return Color(.systemGray3)
        case .stuck:    return .orange
        case .mastered: return .green
        }
    }

    var tintColor: Color {
        switch self {
        case .empty:    return Color(.systemGray3)
        case .stuck:    return .orange
        case .mastered: return .green
        }
    }

    var next: Status {
        switch self {
        case .empty:    return .stuck
        case .stuck:    return .mastered
        case .mastered: return .empty
        }
    }
}
