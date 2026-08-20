//
//  DailyMode.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import SwiftUI

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

    var subtitle: String {
        switch self {
        case .sleeping: return "Ordinary reminders are paused"
        case .work: return "Stay focused and take regular breaks"
        case .idle: return "A gentler reminder schedule is active"
        }
    }

    var icon: String {
        switch self {
        case .sleeping: return "moon.fill"
        case .work: return "briefcase.fill"
        case .idle: return "house.fill"
        }
    }

    var color: Color {
        switch self {
        case .sleeping: return .indigo
        case .work: return .green
        case .idle: return .orange
        }
    }
}
