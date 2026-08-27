//
//  DailyModeProgressCalculator.swift
//  igotu
//

import Foundation

struct DailyModeProgressCalculator {
    private struct ScheduledInterval {
        let mode: DailyMode
        let start: Date
        let end: Date
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func progress(
        for mode: DailyMode,
        schedule: DailySchedule,
        at date: Date
    ) -> Double {
        let intervals = scheduledIntervals(for: schedule, around: date)

        if mode == .idle {
            return idleProgress(from: intervals, at: date) ?? 0.5
        }

        guard let interval = intervals
            .filter({ $0.mode == mode && $0.start <= date && date < $0.end })
            .max(by: { $0.start < $1.start }) else {
            return 0.5
        }

        return normalizedProgress(in: interval, at: date)
    }

    private func idleProgress(
        from intervals: [ScheduledInterval],
        at date: Date
    ) -> Double? {
        let boundaries = intervals.flatMap { [$0.start, $0.end] }.sorted()
        guard let start = boundaries.last(where: { $0 <= date }),
              let end = boundaries.first(where: { $0 > date }),
              end > start else {
            return nil
        }

        let interval = ScheduledInterval(mode: .idle, start: start, end: end)
        return normalizedProgress(in: interval, at: date)
    }

    private func scheduledIntervals(
        for schedule: DailySchedule,
        around date: Date
    ) -> [ScheduledInterval] {
        let day = calendar.startOfDay(for: date)

        return (-2...2).flatMap { offset in
            guard let anchor = calendar.date(byAdding: .day, value: offset, to: day) else {
                return [ScheduledInterval]()
            }

            var intervals: [ScheduledInterval] = []

            if let sleep = makeInterval(
                mode: .sleeping,
                start: schedule.sleepStart,
                end: schedule.sleepEnd,
                on: anchor
            ) {
                intervals.append(sleep)
            }

            if isWorkday(anchor, in: schedule.workdays),
               let work = makeInterval(
                   mode: .work,
                   start: schedule.workStart,
                   end: schedule.workEnd,
                   on: anchor
               ) {
                intervals.append(work)
            }

            return intervals
        }
    }

    private func makeInterval(
        mode: DailyMode,
        start: DateComponents,
        end: DateComponents,
        on anchor: Date
    ) -> ScheduledInterval? {
        let intervalStart = dateAt(start, on: anchor)
        var intervalEnd = dateAt(end, on: anchor)

        if intervalEnd <= intervalStart {
            intervalEnd = calendar.date(byAdding: .day, value: 1, to: intervalEnd) ?? intervalEnd
        }

        guard intervalEnd > intervalStart else { return nil }

        return ScheduledInterval(mode: mode, start: intervalStart, end: intervalEnd)
    }

    private func normalizedProgress(in interval: ScheduledInterval, at date: Date) -> Double {
        let duration = interval.end.timeIntervalSince(interval.start)
        guard duration > 0 else { return 0.5 }

        let elapsed = date.timeIntervalSince(interval.start)
        return min(max(elapsed / duration, 0), 1)
    }

    private func dateAt(_ components: DateComponents, on date: Date) -> Date {
        calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: date
        ) ?? date
    }

    private func isWorkday(_ date: Date, in workdays: Set<Weekday>) -> Bool {
        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) else {
            return false
        }

        return workdays.contains(weekday)
    }
}
