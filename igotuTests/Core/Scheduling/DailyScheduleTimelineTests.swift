import Foundation
import Testing
@testable import igotu

struct DailyScheduleTimelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func workIntervalCrossingMidnightBelongsToItsStartDay() {
        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 3),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 22),
            workEnd: DateComponents(hour: 2),
            workdays: [.monday]
        )
        let timeline = DailyScheduleTimeline(calendar: calendar)
        let tuesdayMorning = date(year: 2026, month: 8, day: 25, hour: 0, minute: 30)

        let interval = timeline.currentInterval(for: schedule, at: tuesdayMorning)

        #expect(interval.mode == .work)
        #expect(interval.start == date(year: 2026, month: 8, day: 24, hour: 22))
        #expect(interval.end == date(year: 2026, month: 8, day: 25, hour: 2))
    }

    @Test func currentWorkIntervalEndsAtConfiguredBoundary() {
        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.thursday]
        )
        let timeline = DailyScheduleTimeline(calendar: calendar)
        let date = self.date(year: 2026, month: 8, day: 27, hour: 17, minute: 50)

        let interval = timeline.currentInterval(for: schedule, at: date)

        #expect(interval.mode == .work)
        #expect(interval.end == self.date(year: 2026, month: 8, day: 27, hour: 18))
    }

    @Test func supportsMultipleWorkPeriodsOnTheSameDay() {
        let schedule = DailySchedule(
            sleepPeriods: [
                period(start: 23, end: 7, days: Set(Weekday.allCases))
            ],
            workPeriods: [
                period(start: 9, end: 12, days: [.monday]),
                period(start: 13, end: 18, days: [.monday])
            ]
        )
        let timeline = DailyScheduleTimeline(calendar: calendar)

        let lunch = timeline.currentInterval(
            for: schedule,
            at: date(year: 2026, month: 8, day: 24, hour: 12, minute: 30)
        )
        let afternoon = timeline.currentInterval(
            for: schedule,
            at: date(year: 2026, month: 8, day: 24, hour: 13, minute: 30)
        )

        #expect(lunch.mode == .idle)
        #expect(afternoon.mode == .work)
    }

    @Test func appliesWorkPeriodsOnlyOnTheirSelectedDays() {
        let schedule = DailySchedule(
            sleepPeriods: [],
            workPeriods: [
                period(start: 9, end: 12, days: [.monday]),
                period(start: 14, end: 17, days: [.tuesday])
            ]
        )
        let timeline = DailyScheduleTimeline(calendar: calendar)

        let monday = timeline.currentInterval(
            for: schedule,
            at: date(year: 2026, month: 8, day: 24, hour: 10)
        )
        let tuesdayMorning = timeline.currentInterval(
            for: schedule,
            at: date(year: 2026, month: 8, day: 25, hour: 10)
        )
        let tuesdayAfternoon = timeline.currentInterval(
            for: schedule,
            at: date(year: 2026, month: 8, day: 25, hour: 15)
        )

        #expect(monday.mode == .work)
        #expect(tuesdayMorning.mode == .idle)
        #expect(tuesdayAfternoon.mode == .work)
    }

    @Test func noWorkPeriodsMeansAwakeTimeIsIdle() {
        let schedule = DailySchedule(
            sleepPeriods: [
                period(start: 23, end: 7, days: Set(Weekday.allCases))
            ],
            workPeriods: []
        )
        let timeline = DailyScheduleTimeline(calendar: calendar)

        let interval = timeline.currentInterval(
            for: schedule,
            at: date(year: 2026, month: 8, day: 24, hour: 10)
        )

        #expect(interval.mode == .idle)
    }

    private func period(
        start: Int,
        end: Int,
        days: Set<Weekday>
    ) -> DailySchedulePeriod {
        DailySchedulePeriod(
            start: DateComponents(hour: start),
            end: DateComponents(hour: end),
            days: days
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
