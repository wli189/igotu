import Foundation

public struct ReminderTestTiming: Codable, Equatable {
    public let notificationDelay: TimeInterval
    public let expirationGracePeriod: TimeInterval
    public let repeatDelay: TimeInterval

    public init(
        notificationDelay: TimeInterval,
        expirationGracePeriod: TimeInterval,
        repeatDelay: TimeInterval
    ) {
        self.notificationDelay = notificationDelay
        self.expirationGracePeriod = expirationGracePeriod
        self.repeatDelay = repeatDelay
    }

    public static let defaultValue = ReminderTestTiming(
        notificationDelay: ReminderTiming.testNotificationDelay,
        expirationGracePeriod: ReminderTiming.testExpirationGracePeriod,
        repeatDelay: ReminderTiming.testRepeatDelay
    )
}

public enum ReminderEventStatus: String, Codable {
    case scheduled
    case delivered
    case acknowledged
    case skipped
    case expired
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .acknowledged, .skipped, .expired, .cancelled:
            return true
        case .scheduled, .delivered:
            return false
        }
    }

    public var countsTowardCompletion: Bool {
        self == .acknowledged
    }

    public var countsTowardCooldown: Bool {
        switch self {
        case .scheduled, .delivered, .acknowledged, .skipped, .expired:
            return true
        case .cancelled:
            return false
        }
    }
}

public struct ReminderEvent: Identifiable, Codable, Equatable {
    public let id: UUID
    public let behavior: Behavior
    public let context: ReminderContext
    public let isTest: Bool
    public let testTiming: ReminderTestTiming?
    public var timestamp: Date
    public var status: ReminderEventStatus
    public var resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        behavior: Behavior,
        context: ReminderContext,
        timestamp: Date,
        isTest: Bool = false,
        testTiming: ReminderTestTiming? = nil,
        status: ReminderEventStatus = .delivered,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.behavior = behavior
        self.context = context
        self.isTest = isTest
        self.testTiming = testTiming
        self.timestamp = timestamp
        self.status = status
        self.resolvedAt = resolvedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, behavior, context, isTest, testTiming, timestamp, status, resolvedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        behavior = try container.decode(Behavior.self, forKey: .behavior)
        context = try container.decode(ReminderContext.self, forKey: .context)
        isTest = try container.decodeIfPresent(Bool.self, forKey: .isTest) ?? false
        testTiming = try container.decodeIfPresent(
            ReminderTestTiming.self,
            forKey: .testTiming
        )
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        status = try container.decode(ReminderEventStatus.self, forKey: .status)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
    }

    public func cooldownAnchor(expirationGracePeriod: TimeInterval) -> Date? {
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
