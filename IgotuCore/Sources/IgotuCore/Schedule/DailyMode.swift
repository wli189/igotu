//
//  DailyMode.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

public enum DailyMode: Equatable, Hashable {
    case sleeping
    case work
    case idle

    /// Modes that can own an explicit schedule period.
    public static var scheduleModes: [DailyMode] {
        [.sleeping, .work]
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

    public var wellnessTheme: WellnessTheme {
        switch self {
        case .sleeping: return .sleep
        case .work: return .work
        case .idle: return .home
        }
    }

    public var key: String {
        switch self {
        case .sleeping: return "sleeping"
        case .work: return "work"
        case .idle: return "idle"
        }
    }

    public init?(key: String) {
        switch key {
        case "sleeping": self = .sleeping
        case "work": self = .work
        case "idle": self = .idle
        default: return nil
        }
    }

}
