//
//  DailyMode.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

enum DailyMode: Equatable {
    case sleeping
    case work
    case idle

    var title: String {
        switch self {
        case .sleeping: return "Sleeping"
        case .work: return "Work"
        case .idle: return "Idle"
        }
    }

    var icon: String {
        switch self {
        case .sleeping: return "moon.fill"
        case .work: return "briefcase.fill"
        case .idle: return "house.fill"
        }
    }

    var wellnessTheme: WellnessTheme {
        switch self {
        case .sleeping: return .sleep
        case .work: return .work
        case .idle: return .home
        }
    }

    var key: String {
        switch self {
        case .sleeping: return "sleeping"
        case .work: return "work"
        case .idle: return "idle"
        }
    }

    init?(key: String) {
        switch key {
        case "sleeping": self = .sleeping
        case "work": self = .work
        case "idle": self = .idle
        default: return nil
        }
    }

}
