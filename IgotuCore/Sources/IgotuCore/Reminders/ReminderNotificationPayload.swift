import Foundation

public struct ReminderNotificationPayload: Equatable {
    private enum Key {
        static let kind = "kind"
        static let version = "version"
        static let eventID = "eventID"
    }

    public static let behaviorKind = "behavior-reminder"
    public static let currentVersion = 1

    public let eventID: UUID

    public init(eventID: UUID) {
        self.eventID = eventID
    }

    public init?(userInfo: [AnyHashable: Any]) {
        guard
            userInfo[Key.kind] as? String == Self.behaviorKind,
            let version = Self.integer(from: userInfo[Key.version]),
            version == Self.currentVersion,
            let eventIDValue = userInfo[Key.eventID] as? String,
            let eventID = UUID(uuidString: eventIDValue)
        else {
            return nil
        }

        self.init(eventID: eventID)
    }

    public var userInfo: [AnyHashable: Any] {
        [
            Key.kind: Self.behaviorKind,
            Key.version: Self.currentVersion,
            Key.eventID: eventID.uuidString
        ]
    }

    public static func eventID(from userInfo: [AnyHashable: Any]) -> UUID? {
        ReminderNotificationPayload(userInfo: userInfo)?.eventID
    }

    private static func integer(from value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? NSNumber {
            return value.intValue
        }

        return nil
    }
}
