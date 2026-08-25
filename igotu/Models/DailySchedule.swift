//
//  DailySchedule.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation

struct DailySchedule: Codable, Equatable {
    var sleepStart: DateComponents
    var sleepEnd: DateComponents
    var workStart: DateComponents
    var workEnd: DateComponents
    var workdays: Set<Weekday>

    init(
        sleepStart: DateComponents,
        sleepEnd: DateComponents,
        workStart: DateComponents,
        workEnd: DateComponents,
        workdays: Set<Weekday> = Weekday.defaultWorkdays
    ) {
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.workStart = workStart
        self.workEnd = workEnd
        self.workdays = workdays
    }

    private enum CodingKeys: String, CodingKey {
        case sleepStart
        case sleepEnd
        case workStart
        case workEnd
        case workdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sleepStart = try container.decode(DateComponents.self, forKey: .sleepStart)
        sleepEnd = try container.decode(DateComponents.self, forKey: .sleepEnd)
        workStart = try container.decode(DateComponents.self, forKey: .workStart)
        workEnd = try container.decode(DateComponents.self, forKey: .workEnd)
        workdays = try container.decodeIfPresent(Set<Weekday>.self, forKey: .workdays)
            ?? Weekday.defaultWorkdays
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sleepStart, forKey: .sleepStart)
        try container.encode(sleepEnd, forKey: .sleepEnd)
        try container.encode(workStart, forKey: .workStart)
        try container.encode(workEnd, forKey: .workEnd)
        try container.encode(workdays, forKey: .workdays)
    }
}

extension DailySchedule {
    func nextSleepStart(
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = sleepStart.hour
        components.minute = sleepStart.minute
        components.second = 0

        guard let sleepStartToday = calendar.date(from: components) else {
            return nil
        }

        guard sleepStartToday <= date else {
            return sleepStartToday
        }

        return calendar.date(byAdding: .day, value: 1, to: sleepStartToday)
    }
}
