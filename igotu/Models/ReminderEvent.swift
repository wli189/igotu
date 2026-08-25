import Foundation

enum ReminderEventStatus: String, Codable {
    case scheduled
    case delivered
    case acknowledged
    case skipped
    case cancelled

    var countsTowardCompletion: Bool {
        self == .acknowledged
    }

    var countsTowardCooldown: Bool {
        switch self {
        case .scheduled, .delivered, .acknowledged:
            return true
        case .skipped, .cancelled:
            return false
        }
    }
}

struct ReminderEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let behavior: Behavior
    let context: ReminderContext
    var timestamp: Date
    var status: ReminderEventStatus
    var resolvedAt: Date?

    init(
        id: UUID = UUID(),
        behavior: Behavior,
        context: ReminderContext,
        timestamp: Date,
        status: ReminderEventStatus = .delivered,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.behavior = behavior
        self.context = context
        self.timestamp = timestamp
        self.status = status
        self.resolvedAt = resolvedAt
    }
}
