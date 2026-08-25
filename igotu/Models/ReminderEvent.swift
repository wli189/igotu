import Foundation

struct ReminderEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let behavior: Behavior
    let context: ReminderContext
    let timestamp: Date

    init(
        id: UUID = UUID(),
        behavior: Behavior,
        context: ReminderContext,
        timestamp: Date
    ) {
        self.id = id
        self.behavior = behavior
        self.context = context
        self.timestamp = timestamp
    }
}
