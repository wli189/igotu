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
