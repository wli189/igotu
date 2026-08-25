//
//  DailyModeManager.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation

struct DailyModeManager {
    private let calendar = Calendar.current
    
    func currentMode(
            for schedule: DailySchedule,
            at date: Date = .now
    ) -> DailyMode {
        let currentMinutes = minutesSinceMidnight(for: date)
        
        let sleepStart = minutes(for: schedule.sleepStart)
        let sleepEnd = minutes(for: schedule.sleepEnd)
        let workStart = minutes(for: schedule.workStart)
        let workEnd = minutes(for: schedule.workEnd)
        
        if isTime(currentMinutes, between: sleepStart, and: sleepEnd) {
            return .sleeping
        } else if isTime(currentMinutes, between: workStart, and: workEnd)
                    && isWorkday(for: date, in: schedule.workdays) {
            return .work
        } else {
            return .idle
        }
    }
    
    private func minutesSinceMidnight(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    
    private func minutes(for components: DateComponents) -> Int {
        (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func isWorkday(for date: Date, in workdays: Set<Weekday>) -> Bool {
        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) else {
            return false
        }

        return workdays.contains(weekday)
    }
    
    private func isTime(
            _ current: Int,
            between start: Int,
            and end: Int
        ) -> Bool {
            if start < end {
                return current >= start && current < end
            } else {
                return current >= start || current < end
            }
        }
}
