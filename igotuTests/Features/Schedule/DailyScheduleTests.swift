import Foundation
import Testing
import IgotuCore
@testable import igotu

struct DailyScheduleTests {
    private var calendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    private let schedule = DailySchedule(
        sleepStart: DateComponents(hour: 23, minute: 0),
        sleepEnd: DateComponents(hour: 7, minute: 0),
        workStart: DateComponents(hour: 9, minute: 0),
        workEnd: DateComponents(hour: 18, minute: 0)
    )

    @Test func nextSleepStartUsesTonightWhenBedtimeHasNotPassed() {
        let date = makeDate(day: 26, hour: 20)

        let result = schedule.nextSleepStart(after: date, calendar: calendar)

        #expect(result == makeDate(day: 26, hour: 23))
    }

    @Test func nextSleepStartUsesTomorrowAfterBedtime() {
        let date = makeDate(day: 26, hour: 23, minute: 30)

        let result = schedule.nextSleepStart(after: date, calendar: calendar)

        #expect(result == makeDate(day: 27, hour: 23))
    }

    @Test func nextSleepStartUsesTheNextSelectedDay() {
        let schedule = DailySchedule(
            sleepPeriods: [
                DailySchedulePeriod(
                    start: DateComponents(hour: 22),
                    end: DateComponents(hour: 6),
                    days: [.friday]
                )
            ],
            workPeriods: []
        )
        let date = makeDate(day: 24, hour: 20)

        let result = schedule.nextSleepStart(after: date, calendar: calendar)

        #expect(result == makeDate(day: 28, hour: 22))
    }

    @Test func storesPeriodsByModeAndKeepsLegacyAccessors() throws {
        let workPeriod = DailySchedulePeriod(
            start: DateComponents(hour: 9),
            end: DateComponents(hour: 17),
            days: Weekday.defaultWorkdays
        )
        let schedule = DailySchedule(periodsByMode: [.work: [workPeriod]])

        #expect(schedule.periods(for: .work) == [workPeriod])
        #expect(schedule.workPeriods == [workPeriod])
        #expect(schedule.sleepPeriods.isEmpty)
        #expect(schedule.scheduledModes == [.work])

        let restored = try JSONDecoder().decode(
            DailySchedule.self,
            from: JSONEncoder().encode(schedule)
        )
        #expect(restored == schedule)
    }

    @Test func removingTheLastPeriodRemovesTheModeEntry() {
        var schedule = DailySchedule(
            periodsByMode: [
                .sleeping: [
                    DailySchedulePeriod(
                        start: DateComponents(hour: 23),
                        end: DateComponents(hour: 7),
                        days: Set(Weekday.allCases)
                    )
                ]
            ]
        )

        schedule.setPeriods([], for: .sleeping)

        #expect(schedule.periodsByMode.isEmpty)
        #expect(schedule.scheduledModes.isEmpty)
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
