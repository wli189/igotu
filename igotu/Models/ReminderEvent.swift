import Foundation

enum ReminderEventStatus: String, Codable {
    case scheduled
    case delivered
    case acknowledged
    case skipped
    case expired
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .acknowledged, .skipped, .expired, .cancelled:
            return true
        case .scheduled, .delivered:
            return false
        }
    }

    var countsTowardCompletion: Bool {
        self == .acknowledged
    }

    var countsTowardCooldown: Bool {
        switch self {
        case .scheduled, .delivered, .acknowledged, .skipped, .expired:
            return true
        case .cancelled:
            return false
        }
    }
}

struct ReminderEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let behavior: Behavior
    let context: ReminderContext
    let isTest: Bool
    var timestamp: Date
    var status: ReminderEventStatus
    var resolvedAt: Date?

    init(
        id: UUID = UUID(),
        behavior: Behavior,
        context: ReminderContext,
        timestamp: Date,
        isTest: Bool = false,
        status: ReminderEventStatus = .delivered,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.behavior = behavior
        self.context = context
        self.isTest = isTest
        self.timestamp = timestamp
        self.status = status
        self.resolvedAt = resolvedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, behavior, context, isTest, timestamp, status, resolvedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        behavior = try container.decode(Behavior.self, forKey: .behavior)
        context = try container.decode(ReminderContext.self, forKey: .context)
        isTest = try container.decodeIfPresent(Bool.self, forKey: .isTest) ?? false
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        status = try container.decode(ReminderEventStatus.self, forKey: .status)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
    }

    func cooldownAnchor(expirationGracePeriod: TimeInterval) -> Date? {
        switch status {
        case .scheduled, .delivered:
            return timestamp
        case .acknowledged, .skipped:
            return resolvedAt ?? timestamp
        case .expired:
            return timestamp.addingTimeInterval(expirationGracePeriod)
        case .cancelled:
            return nil
        }
    }
}
