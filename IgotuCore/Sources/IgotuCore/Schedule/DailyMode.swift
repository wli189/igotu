//
//  DailyMode.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

public enum DailyMode: String, Codable, CaseIterable, Equatable, Hashable {
    case sleeping
    case work
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
        case .idle: return "Idle"
        }
    }

    public var icon: String {
        switch self {
        case .sleeping: return "moon.fill"
        case .work: return "briefcase.fill"
        case .idle: return "house.fill"
        }
    }

    public var nudgeTitle: String {
        switch self {
        case .sleeping: return "Rest easy"
        case .work: return "A small pause goes a long way"
        case .idle: return "Move at your own pace"
        }
    }

    public var startTitle: String {
        switch self {
        case .sleeping: return "Bedtime"
        case .work: return "Work starts"
        case .idle: return "Starts"
        }
    }

    public var endTitle: String {
        switch self {
        case .sleeping: return "Wake up"
        case .work: return "Work ends"
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

    public var reminderContext: ReminderContext? {
        switch self {
        case .sleeping: return nil
        case .work: return .work
        case .idle: return .idle
        }
    }

    /// Lower values win when explicit periods overlap. Sleeping keeps its
    /// existing priority, while new scheduled modes remain deterministic.
    public var timelinePriority: Int {
        switch self {
        case .sleeping: return 0
        case .work: return 1
        case .idle: return Int.max
        }
    }

    public var wellnessTheme: WellnessTheme {
        switch self {
        case .sleeping: return .sleep
        case .work: return .work
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
