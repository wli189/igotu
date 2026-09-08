//
//  Behavior.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

public enum Behavior: String, CaseIterable, Codable, Identifiable {
    case hydration
    case standUp
    case movement

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hydration: return "Drink Water"
        case .standUp: return "Stand Up"
        case .movement: return "Move Around"
        }
    }

    public var icon: String {
        switch self {
        case .hydration: return "drop.fill"
        case .standUp: return "figure.stand"
        case .movement: return "figure.walk"
        }
    }

    public var reminderPriority: Int {
        switch self {
        case .standUp: return 0
        case .hydration: return 1
        case .movement: return 2
        }
    }

    public var reminderMessage: String {
        switch self {
        case .hydration:
            return "Take a moment to drink some water."
        case .standUp:
            return "Stand up and stretch for a moment."
        case .movement:
            return "Take a short walk or move around."
        }
    }
}
