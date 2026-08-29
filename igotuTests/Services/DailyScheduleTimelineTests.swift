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
