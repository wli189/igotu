import ActivityKit
import Foundation

struct WellnessReminderAttributes: ActivityAttributes {
    enum ReminderState: String, Codable, Hashable {
        case pending
        case acknowledged
        case skipped
    }

    struct ContentState: Codable, Hashable {
        var status: ReminderState
        var dueAt: Date
    }

    let eventID: UUID
    let behavior: String
    let icon: String
    let message: String
}
