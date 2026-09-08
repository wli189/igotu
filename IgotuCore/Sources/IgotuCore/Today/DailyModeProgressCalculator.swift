//
//  DailyModeProgressCalculator.swift
//  igotu
//

import Foundation

public struct DailyModeProgressCalculator {
    private let timeline: DailyScheduleTimeline

    public init(calendar: Calendar = .current) {
        timeline = DailyScheduleTimeline(calendar: calendar)
    }

    public func progress(
        for mode: DailyMode,
        schedule: DailySchedule,
        at date: Date
    ) -> Double {
        let interval = timeline.currentInterval(for: schedule, at: date)
        guard interval.mode == mode else {
            return 0.5
        }

        return normalizedProgress(in: interval, at: date)
    }

    private func normalizedProgress(in interval: DailyScheduleInterval, at date: Date) -> Double {
        let duration = interval.end.timeIntervalSince(interval.start)
        guard duration > 0 else { return 0.5 }

        let elapsed = date.timeIntervalSince(interval.start)
        return min(max(elapsed / duration, 0), 1)
    }
}
