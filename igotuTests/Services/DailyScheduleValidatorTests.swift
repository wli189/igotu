import Foundation
import Testing
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
}
