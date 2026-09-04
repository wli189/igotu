import Foundation

public struct ScheduledTestNotification: Identifiable, Equatable {
    public enum Kind: Equatable {
        case behavior(Behavior)
        case sleepReminder

        public var title: String {
            switch self {
            case let .behavior(behavior):
                return behavior.title
            case .sleepReminder:
                return "Wind Down"
            }
        }

        public var icon: String {
            switch self {
            case let .behavior(behavior):
                return behavior.icon
            case .sleepReminder:
                return "moon.zzz.fill"
            }
        }
    }

    public let id: String
    public let kind: Kind
    public let fireDate: Date

    public init(id: String, kind: Kind, fireDate: Date) {
        self.id = id
        self.kind = kind
        self.fireDate = fireDate
    }
}
