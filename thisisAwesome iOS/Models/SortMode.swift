import Foundation

enum SortMode: String, CaseIterable, Identifiable {
    case dateDesc, dateAsc, locationAZ, locationZA

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateDesc: return "Date (newest)"
        case .dateAsc: return "Date (oldest)"
        case .locationAZ: return "Location A–Z"
        case .locationZA: return "Location Z–A"
        }
    }
}
