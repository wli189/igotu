//
//  DailyMode.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

public struct ReminderPolicy: Equatable {
    public let allowedBehaviors: Set<Behavior>
    public let defaultBehaviors: Set<Behavior>

    public init(
        allowedBehaviors: Set<Behavior>,
        defaultBehaviors: Set<Behavior>
    ) {
        self.allowedBehaviors = allowedBehaviors
        self.defaultBehaviors = defaultBehaviors
    }
}

public enum DailyMode: String, Codable, CaseIterable, Equatable, Hashable {
    case sleeping
    case work
    case study
    case idle

    /// Modes that can own an explicit schedule period.
    public static var scheduleModes: [DailyMode] {
        allCases.filter(\.isSchedulable)
    }

    public static let defaultScheduleMode: DailyMode = .work

    public var isSchedulable: Bool {
        self != .idle
    }

    public var title: String {
        switch self {
        case .sleeping: return "Sleeping"
        case .work: return "Work"
        case .study: return "Study"
        case .idle: return "Idle"
        }
    }

    public var icon: String {
        switch self {
        case .sleeping: return "moon.fill"
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .idle: return "house.fill"
        }
    }

    public var nudgeTitle: String {
        switch self {
        case .sleeping: return "Rest easy"
        case .work: return "A small pause goes a long way"
        case .study: return "Protect your focus with small pauses"
        case .idle: return "Move at your own pace"
        }
    }

    public var startTitle: String {
        switch self {
        case .sleeping: return "Bedtime"
        case .work: return "Work starts"
        case .study: return "Study starts"
        case .idle: return "Starts"
        }
    }

    public var endTitle: String {
        switch self {
        case .sleeping: return "Wake up"
        case .work: return "Work ends"
        case .study: return "Study ends"
        case .idle: return "Ends"
        }
    }

    public var defaultStartHour: Int {
        self == .sleeping ? 23 : 9
    }

    public var defaultEndHour: Int {
        self == .sleeping ? 7 : 18
    }

    public var defaultDays: Set<Weekday> {
        self == .sleeping ? Set(Weekday.allCases) : Weekday.defaultWorkdays
    }

    public var reminderPolicy: ReminderPolicy {
        switch self {
        case .sleeping:
            return ReminderPolicy(allowedBehaviors: [], defaultBehaviors: [])
        case .work:
            return ReminderPolicy(
                allowedBehaviors: [.hydration, .standUp, .movement],
                defaultBehaviors: [.hydration, .standUp, .movement]
            )
        case .study:
            return ReminderPolicy(
                allowedBehaviors: [.hydration, .standUp],
                defaultBehaviors: [.hydration, .standUp]
            )
        case .idle:
            return ReminderPolicy(
                allowedBehaviors: [.hydration, .movement],
                defaultBehaviors: [.hydration, .movement]
            )
        }
    }

    public var reminderContext: ReminderContext? {
        switch self {
        case .sleeping: return nil
        case .work: return .work
        case .study: return .study
        case .idle: return .idle
        }
    }

    /// Lower values win when explicit periods overlap. Sleeping keeps its
    /// existing priority, while new scheduled modes remain deterministic.
    public var timelinePriority: Int {
        switch self {
        case .sleeping: return 0
        case .work: return 1
        case .study: return 2
        case .idle: return Int.max
        }
    }

    public var wellnessTheme: WellnessTheme {
        switch self {
        case .sleeping: return .sleep
        case .work: return .work
        case .study: return .study
        case .idle: return .home
        }
    }

    public var key: String {
        rawValue
    }

    public init?(key: String) {
        self.init(rawValue: key)
    }

}
