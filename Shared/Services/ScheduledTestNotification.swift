import Foundation

struct ScheduledTestNotification: Identifiable, Equatable {
    enum Kind: Equatable {
        case behavior(Behavior)
        case sleepReminder

        var title: String {
            switch self {
            case let .behavior(behavior):
                return behavior.title
            case .sleepReminder:
                return "Wind Down"
            }
        }

        var icon: String {
            switch self {
            case let .behavior(behavior):
                return behavior.icon
            case .sleepReminder:
                return "moon.zzz.fill"
            }
        }
    }

    let id: String
    let kind: Kind
    let fireDate: Date
}
