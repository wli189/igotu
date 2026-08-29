import Foundation
import Testing
@testable import igotu

struct ReminderPlannerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func currentCandidateCrossingWorkBoundaryUsesNextAwakeMode() {
        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.thursday]
        )
        let now = date(year: 2026, month: 8, day: 27, hour: 17, minute: 50)
        let planner = ReminderPlanner(
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            timeline: DailyScheduleTimeline(calendar: calendar)
        )

        let candidates = planner.nextReminders(
            for: schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [],
            now: now
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.mode == .idle)
        #expect(candidates.first?.dueAt == date(year: 2026, month: 8, day: 27, hour: 19))
    }

    @Test func plannerFindsNextWorkIntervalAcrossCustomWorkweek() {
        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.monday]
        )
        let now = date(year: 2026, month: 8, day: 25, hour: 17, minute: 50)
        let planner = ReminderPlanner(
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            timeline: DailyScheduleTimeline(calendar: calendar)
        )

        let candidates = planner.nextReminders(
            for: schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            idleRules: [],
            recentEvents: [],
            now: now
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.mode == .work)
        #expect(candidates.first?.dueAt == date(year: 2026, month: 8, day: 31, hour: 10))
    }

    @Test func validPendingReminderKeepsItsOriginalDueDate() {
        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.thursday]
        )
        let now = date(year: 2026, month: 8, day: 27, hour: 10)
        let pendingDueAt = date(year: 2026, month: 8, day: 27, hour: 12, minute: 30)
        let pendingReminder = ScheduledReminder(
            eventID: UUID(),
            candidate: ReminderCandidate(
                behavior: .hydration,
                mode: .work,
                dueAt: pendingDueAt
            )
        )
        let planner = ReminderPlanner(
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            timeline: DailyScheduleTimeline(calendar: calendar)
        )

        let candidates = planner.nextReminders(
            for: schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            idleRules: [],
            recentEvents: [],
            pendingReminders: [pendingReminder],
            now: now
        )

        #expect(candidates == [pendingReminder.candidate])
    }

    @Test func pendingReminderDuringSleepIsReplannedForNextValidInterval() {
        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.thursday]
        )
        let now = date(year: 2026, month: 8, day: 27, hour: 22)
        let pendingReminder = ScheduledReminder(
            eventID: UUID(),
            candidate: ReminderCandidate(
                behavior: .hydration,
                mode: .idle,
                dueAt: date(year: 2026, month: 8, day: 27, hour: 23, minute: 30)
            )
        )
        let planner = ReminderPlanner(
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            timeline: DailyScheduleTimeline(calendar: calendar)
        )

        let candidates = planner.nextReminders(
            for: schedule,
            workRules: [],
            idleRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [],
            pendingReminders: [pendingReminder],
            now: now
        )

        #expect(candidates.first?.mode == .idle)
        #expect(candidates.first?.dueAt == date(year: 2026, month: 8, day: 28, hour: 8))
        #expect(candidates.first?.dueAt != pendingReminder.candidate.dueAt)
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
