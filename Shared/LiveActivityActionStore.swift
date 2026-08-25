import Foundation

enum LiveActivityActionStatus: String, Codable, Hashable {
    case acknowledged
    case skipped
}

struct LiveActivityAction: Codable, Equatable {
    let eventID: UUID
    let status: LiveActivityActionStatus
    let date: Date
}

enum LiveActivityActionStore {
    static let appGroupIdentifier = "group.brian.igotu"

    private static let actionsKey = "liveActivityActions"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func record(
        eventID: UUID,
        status: LiveActivityActionStatus,
        date: Date = .now,
        defaults: UserDefaults = sharedDefaults
    ) {
        var actions = load(from: defaults)
        actions.append(LiveActivityAction(eventID: eventID, status: status, date: date))

        guard let data = try? JSONEncoder().encode(actions) else {
            return
        }

        defaults.set(data, forKey: actionsKey)
    }

    static func consume(
        defaults: UserDefaults = sharedDefaults
    ) -> [LiveActivityAction] {
        let actions = load(from: defaults)
        defaults.removeObject(forKey: actionsKey)
        return actions
    }

    private static func load(from defaults: UserDefaults) -> [LiveActivityAction] {
        guard
            let data = defaults.data(forKey: actionsKey),
            let actions = try? JSONDecoder().decode([LiveActivityAction].self, from: data)
        else {
            return []
        }

        return actions
    }
}
