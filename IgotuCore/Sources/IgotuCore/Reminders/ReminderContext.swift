public enum ReminderContext: String, Codable {
    case work
    case study
    case idle

    public var title: String {
        switch self {
        case .work: return "Work"
        case .study: return "Study"
        case .idle: return "Idle"
        }
    }

    public var mode: DailyMode {
        switch self {
        case .work: return .work
        case .study: return .study
        case .idle: return .idle
        }
    }

    public var wellnessTheme: WellnessTheme {
        mode.wellnessTheme
    }
}
