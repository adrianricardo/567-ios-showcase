import SwiftUI

enum Category: String, Codable, CaseIterable, Identifiable {
    case turn, exit, basic, combo, footwork, other
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum MovesFilter: String, CaseIterable, Identifiable {
    case named, unnamed, excluded, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .named:    return "Named"
        case .unnamed:  return "Unnamed"
        case .excluded: return "Excluded"
        case .all:      return "All"
        }
    }
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
