import Foundation

struct ReminderNotificationPayload: Equatable {
    private enum Key {
        static let eventID = "eventID"
        static let behavior = "behavior"
        static let mode = "mode"
        static let dueAt = "dueAt"
    }

    let eventID: UUID
    let candidate: ReminderCandidate

    init(eventID: UUID, candidate: ReminderCandidate) {
        self.eventID = eventID
        self.candidate = candidate
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard
            let eventID = Self.eventID(from: userInfo),
            let behaviorValue = userInfo[Key.behavior] as? String,
            let behavior = Behavior(rawValue: behaviorValue),
            let modeValue = userInfo[Key.mode] as? String,
            let mode = DailyMode(key: modeValue),
            let dueAt = Self.date(from: userInfo[Key.dueAt])
        else {
            return nil
        }

        self.init(
            eventID: eventID,
            candidate: ReminderCandidate(
                behavior: behavior,
                mode: mode,
                dueAt: dueAt
            )
        )
    }

    var userInfo: [AnyHashable: Any] {
        [
            Key.eventID: eventID.uuidString,
            Key.behavior: candidate.behavior.rawValue,
            Key.mode: candidate.mode.key,
            Key.dueAt: candidate.dueAt.timeIntervalSince1970
        ]
    }

    static func eventID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard
            let value = userInfo[Key.eventID] as? String,
            let eventID = UUID(uuidString: value)
        else {
            return nil
        }

        return eventID
    }

    private static func date(from value: Any?) -> Date? {
        if let seconds = value as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }

        if let seconds = value as? NSNumber {
            return Date(timeIntervalSince1970: seconds.doubleValue)
        }

        return nil
    }
}
