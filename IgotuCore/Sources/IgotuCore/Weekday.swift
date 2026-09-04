import Foundation

public enum Weekday: Int, CaseIterable, Codable, Hashable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    public var shortTitle: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    public static let defaultWorkdays: Set<Weekday> = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday
    ]

    public static let mondayFirst: [Weekday] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday
    ]
}
