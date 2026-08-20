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
        workEnd: DateComponents(hour: 18)
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

    func testLateNightIsSleeping() {
        let mode = manager.currentMode(for: schedule, at: date(hour: 23, minute: 30))

        XCTAssertEqual(mode, .sleeping)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(hour: hour, minute: minute)
        )!
    }
}
