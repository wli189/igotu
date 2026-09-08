import Foundation
import Testing
import IgotuCore
@testable import igotu

struct DailyModeProgressCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let schedule = DailySchedule(
        sleepStart: DateComponents(hour: 23),
        sleepEnd: DateComponents(hour: 7),
        workStart: DateComponents(hour: 9),
        workEnd: DateComponents(hour: 18),
        workdays: Weekday.defaultWorkdays
    )

    @Test func idleProgressReflectsElapsedMorningTime() {
        let calculator = DailyModeProgressCalculator(calendar: calendar)
        let progress = calculator.progress(
            for: .idle,
            schedule: schedule,
            at: makeDate(day: 27, hour: 8)
        )

        #expect(progress == 0.5)
    }

    @Test func idleProgressReflectsElapsedEveningTime() {
        let calculator = DailyModeProgressCalculator(calendar: calendar)
        let progress = calculator.progress(
            for: .idle,
            schedule: schedule,
            at: makeDate(day: 27, hour: 20)
        )

        #expect(abs(progress - 0.4) < 0.001)
    }

    @Test func nonWorkdayIdleProgressUsesTheWholeWakingWindow() {
        let calculator = DailyModeProgressCalculator(calendar: calendar)
        let progress = calculator.progress(
            for: .idle,
            schedule: schedule,
            at: makeDate(day: 29, hour: 10)
        )

        #expect(abs(progress - 0.1875) < 0.001)
    }

    @Test func sleepingProgressStillHandlesAnIntervalThatCrossesMidnight() {
        let calculator = DailyModeProgressCalculator(calendar: calendar)
        let progress = calculator.progress(
            for: .sleeping,
            schedule: schedule,
            at: makeDate(day: 27, hour: 1)
        )

        #expect(abs(progress - 0.25) < 0.001)
    }

    private func makeDate(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
