//
//  ReminderFrequency.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation

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

    var interval: TimeInterval {
        switch self {
        case .occasional: return 2 * 60 * 60
        case .regular: return 60 * 60
        case .frequent: return 30 * 60
        }
    }

    /// Keeps reminders from landing on the exact same minute every time.
    var offsetRange: ClosedRange<TimeInterval> {
        switch self {
        case .occasional: return -12 * 60 ... 12 * 60
        case .regular: return -7 * 60 ... 7 * 60
        case .frequent: return -3 * 60 ... 3 * 60
        }
    }
}
