//
//  DailyModeManagerTests.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation
import XCTest
@testable import igotu

final class DailyModeManagerTests: XCTestCase {
    private let manager = DailyModeManager()

    private let schedule = DailySchedule(
        sleepStart: DateComponents(hour: 23),
        sleepEnd: DateComponents(hour: 7),
        workStart: DateComponents(hour: 9),
        workEnd: DateComponents(hour: 18),
        workdays: Set(Weekday.allCases)
    )

    func testEarlyMorningIsSleeping() {
        let mode = manager.currentMode(for: schedule, at: date(hour: 6, minute: 30))

        XCTAssertEqual(mode, .sleeping)
    }

    func testWorkHoursAreWork() {
        let mode = manager.currentMode(for: schedule, at: date(hour: 10))

        XCTAssertEqual(mode, .work)
    }

    func testEveningOutsideWorkAndSleepIsIdle() {
        let mode = manager.currentMode(for: schedule, at: date(hour: 20))

        XCTAssertEqual(mode, .idle)
    }

    func testNonWorkdayDuringWorkHoursIsIdle() {
        let weekdaySchedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: Weekday.defaultWorkdays
        )

        let mode = manager.currentMode(
            for: weekdaySchedule,
            at: date(year: 2026, month: 8, day: 30, hour: 10)
        )

        XCTAssertEqual(mode, .idle)
    }

    func testSelectedWeekendDuringWorkHoursIsWork() {
        let weekendSchedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.saturday]
        )

        let mode = manager.currentMode(
            for: weekendSchedule,
            at: date(year: 2026, month: 8, day: 29, hour: 10)
        )

        XCTAssertEqual(mode, .work)
    }

    func testLateNightIsSleeping() {
        let mode = manager.currentMode(for: schedule, at: date(hour: 23, minute: 30))

        XCTAssertEqual(mode, .sleeping)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(hour: hour, minute: minute)
        )!
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
