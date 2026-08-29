import Foundation

struct DailyScheduleInterval: Equatable {
    let mode: DailyMode
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

struct DailyScheduleTimeline {
    private struct ExplicitInterval {
        let mode: DailyMode
        let start: Date
        let end: Date

        func contains(_ date: Date) -> Bool {
            start <= date && date < end
        }
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func currentInterval(
        for schedule: DailySchedule,
        at date: Date = .now
    ) -> DailyScheduleInterval {
        let intervals = scheduleIntervals(for: schedule, around: date, dayRadius: 4)

        return intervals.first(where: { $0.contains(date) })
            ?? fallbackInterval(at: date)
    }

    func intervals(
        for schedule: DailySchedule,
        startingAt date: Date = .now,
        count: Int
    ) -> [DailyScheduleInterval] {
        guard count > 0 else { return [] }

        let intervals = scheduleIntervals(
            for: schedule,
            around: date,
            dayRadius: max(4, count + 2)
        )
        guard let currentIndex = intervals.firstIndex(where: { $0.contains(date) }) else {
            return []
        }

        let endIndex = min(currentIndex + count, intervals.count)
        return Array(intervals[currentIndex..<endIndex])
    }

    private func scheduleIntervals(
        for schedule: DailySchedule,
        around date: Date,
        dayRadius: Int
    ) -> [DailyScheduleInterval] {
        let day = calendar.startOfDay(for: date)
        guard
            let rangeStart = calendar.date(byAdding: .day, value: -dayRadius, to: day),
            let rangeEnd = calendar.date(byAdding: .day, value: dayRadius + 1, to: day)
        else {
            return []
        }

        var explicitIntervals: [ExplicitInterval] = []
        var boundaries = Set([rangeStart, rangeEnd])

        for offset in (-dayRadius)...dayRadius {
            guard let anchor = calendar.date(byAdding: .day, value: offset, to: day) else {
                continue
            }

            if let sleep = makeInterval(
                mode: .sleeping,
                start: schedule.sleepStart,
                end: schedule.sleepEnd,
                on: anchor
            ) {
                explicitIntervals.append(sleep)
                boundaries.insert(sleep.start)
                boundaries.insert(sleep.end)
            }

            if isWorkday(anchor, in: schedule.workdays),
               let work = makeInterval(
                   mode: .work,
                   start: schedule.workStart,
                   end: schedule.workEnd,
                   on: anchor
               ) {
                explicitIntervals.append(work)
                boundaries.insert(work.start)
                boundaries.insert(work.end)
            }

            boundaries.insert(anchor)
        }

        let sortedBoundaries = boundaries.sorted()
        guard sortedBoundaries.count > 1 else { return [] }

        var intervals: [DailyScheduleInterval] = []

        for pair in zip(sortedBoundaries, sortedBoundaries.dropFirst()) {
            let start = pair.0
            let end = pair.1
            guard end > start else { continue }

            let midpoint = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
            let mode = mode(at: midpoint, within: explicitIntervals)
            let interval = DailyScheduleInterval(mode: mode, start: start, end: end)

            if intervals.last?.mode == mode, intervals.last?.end == start {
                intervals[intervals.count - 1] = DailyScheduleInterval(
                    mode: mode,
                    start: intervals[intervals.count - 1].start,
                    end: end
                )
            } else {
                intervals.append(interval)
            }
        }

        return intervals
    }

    private func makeInterval(
        mode: DailyMode,
        start: DateComponents,
        end: DateComponents,
        on anchor: Date
    ) -> ExplicitInterval? {
        guard
            let intervalStart = dateAt(start, on: anchor),
            var intervalEnd = dateAt(end, on: anchor)
        else {
            return nil
        }

        if intervalEnd <= intervalStart {
            intervalEnd = calendar.date(byAdding: .day, value: 1, to: intervalEnd) ?? intervalEnd
        }

        guard intervalEnd > intervalStart else { return nil }
        return ExplicitInterval(mode: mode, start: intervalStart, end: intervalEnd)
    }

    private func mode(
        at date: Date,
        within intervals: [ExplicitInterval]
    ) -> DailyMode {
        if intervals.contains(where: { $0.mode == .sleeping && $0.contains(date) }) {
            return .sleeping
        }

        if intervals.contains(where: { $0.mode == .work && $0.contains(date) }) {
            return .work
        }

        return .idle
    }

    private func dateAt(_ components: DateComponents, on date: Date) -> Date? {
        calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: date
        )
    }

    private func isWorkday(_ date: Date, in workdays: Set<Weekday>) -> Bool {
        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) else {
            return false
        }

        return workdays.contains(weekday)
    }

    private func fallbackInterval(at date: Date) -> DailyScheduleInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return DailyScheduleInterval(mode: .idle, start: start, end: end)
    }
}
