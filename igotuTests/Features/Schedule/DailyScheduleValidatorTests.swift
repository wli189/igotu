import Foundation
import Testing
import IgotuCore
@testable import igotu

struct DailyScheduleValidatorTests {
    private let validator = DailyScheduleValidator()

    @Test func rejectsMatchingSleepTimes() {
        let schedule = schedule(
            sleepStart: 23,
            sleepEnd: 23,
            workStart: 9,
            workEnd: 18
        )

        #expect(validator.issue(for: schedule) == .sleepTimesMatch)
    }

    @Test func rejectsMatchingWorkTimes() {
        let schedule = schedule(
            sleepStart: 23,
            sleepEnd: 7,
            workStart: 9,
            workEnd: 9
        )

        #expect(validator.issue(for: schedule) == .workTimesMatch)
    }

    @Test func detectsOverlapAcrossMidnight() {
        let schedule = schedule(
            sleepStart: 23,
            sleepEnd: 7,
            workStart: 22,
            workEnd: 2
        )

        #expect(validator.issue(for: schedule) == .sleepAndWorkOverlap)
    }

    @Test func acceptsNonOverlappingIntervals() {
        let schedule = schedule(
            sleepStart: 23,
            sleepEnd: 7,
            workStart: 9,
            workEnd: 18
        )

        #expect(validator.issue(for: schedule) == nil)
    }

    @Test func acceptsMultipleNonOverlappingWorkPeriodsOnTheSameDay() {
        let schedule = DailySchedule(
            sleepPeriods: [
                period(start: 23, end: 7, days: Set(Weekday.allCases))
            ],
            workPeriods: [
                period(start: 9, end: 12, days: [.monday]),
                period(start: 13, end: 18, days: [.monday])
            ]
        )

        #expect(validator.issue(for: schedule) == nil)
    }

    @Test func rejectsOverlappingWorkPeriodsOnTheSameDay() {
        let schedule = DailySchedule(
            sleepPeriods: [],
            workPeriods: [
                period(start: 9, end: 13, days: [.monday]),
                period(start: 12, end: 18, days: [.monday])
            ]
        )

        #expect(validator.issue(for: schedule) == .workPeriodsOverlap)
    }

    @Test func rejectsMultipleSleepSchedulesSelectedForTheSameDay() {
        let schedule = DailySchedule(
            sleepPeriods: [
                period(start: 22, end: 6, days: [.monday]),
                period(start: 10, end: 12, days: [.monday])
            ],
            workPeriods: []
        )

        #expect(validator.issue(for: schedule) == .sleepPeriodsOverlap)
    }

    @Test func rejectsWorkOverlappingSleepOnAdjacentScheduleDays() {
        let schedule = DailySchedule(
            sleepPeriods: [
                period(start: 23, end: 7, days: [.monday])
            ],
            workPeriods: [
                period(start: 6, end: 9, days: [.tuesday])
            ]
        )

        #expect(validator.issue(for: schedule) == .sleepAndWorkOverlap)
    }

    private func schedule(
        sleepStart: Int,
        sleepEnd: Int,
        workStart: Int,
        workEnd: Int
    ) -> DailySchedule {
        DailySchedule(
            sleepStart: DateComponents(hour: sleepStart),
            sleepEnd: DateComponents(hour: sleepEnd),
            workStart: DateComponents(hour: workStart),
            workEnd: DateComponents(hour: workEnd)
        )
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
}
