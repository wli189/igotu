enum ReminderContext: String, Codable {
    case work
    case idle

    var title: String {
        switch self {
        case .work: return "Work"
        case .idle: return "Idle"
        }
    }
}
