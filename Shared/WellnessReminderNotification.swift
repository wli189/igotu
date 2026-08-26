import Foundation

enum WellnessReminderNotification {
    static let categoryIdentifier = "wellness-reminder"
    static let identifierPrefix = "wellness-reminder-"

    static func identifier(for eventID: UUID) -> String {
        "\(identifierPrefix)\(eventID.uuidString)"
    }
}
