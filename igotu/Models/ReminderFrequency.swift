//
//  ReminderFrequency.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

enum ReminderFrequency: String, CaseIterable, Codable, Identifiable {
    case occasional
    case regular
    case frequent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .occasional: return "Occasional"
        case .regular: return "Regular"
        case .frequent: return "Frequent"
        }
    }
}
