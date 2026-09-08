import Foundation
import Testing
import IgotuCore
@testable import igotu

struct DailyMetricsCalculatorTests {
    @Test func standingRemindersInTheSameHourCountOnce() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 26,
            hour: 9
        ))!
        let events = [
            ReminderEvent(
                behavior: .standUp,
                context: .work,
                timestamp: day,
                status: .acknowledged,
                resolvedAt: day.addingTimeInterval(10 * 60)
            ),
            ReminderEvent(
                behavior: .standUp,
                context: .work,
                timestamp: day,
                status: .acknowledged,
                resolvedAt: day.addingTimeInterval(40 * 60)
            ),
            ReminderEvent(
                behavior: .standUp,
                context: .work,
                timestamp: day,
                status: .acknowledged,
                resolvedAt: day.addingTimeInterval(60 * 60)
            ),
            ReminderEvent(
                behavior: .hydration,
                context: .work,
                timestamp: day,
                status: .acknowledged,
                resolvedAt: day
            )
        ]

        let metrics = DailyMetricsCalculator().calculate(
            events: events,
            goals: DailyGoals(hydrationCount: 8, standingHours: 8),
            calendar: calendar
        )

        #expect(metrics.hydrationCount == 1)
        #expect(metrics.standingHours == 2)
    }
}
