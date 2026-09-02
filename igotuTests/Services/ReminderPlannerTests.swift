import Foundation
import Testing
@testable import igotu

struct ReminderPlannerTests {
    private let planner = ReminderPlanner(
        engine: ReminderEngine(offsetProvider: { _ in 0 }),
        timeline: DailyScheduleTimeline(calendar: Self.calendar)
    )
    private let now = Self.date(year: 2026, month: 8, day: 27, hour: 17, minute: 50)

    @Test func workToIdleBoundaryUsesIdleRules() {
        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            events: [],
            now: now
        )

        #expect(plan.reminders.count == 1)
        #expect(plan.reminders.first?.candidate.mode == .idle)
        #expect(plan.reminders.first?.candidate.dueAt == Self.date(
            year: 2026,
            month: 8,
            day: 27,
            hour: 19
        ))
    }

    @Test func exactWorkEndIsAlreadyIdle() {
        let boundary = Self.date(year: 2026, month: 8, day: 27, hour: 18)
        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            events: [],
            now: boundary
        )

        #expect(plan.reminders.first?.candidate.mode == .idle)
        #expect(plan.reminders.first?.candidate.dueAt == Self.date(
            year: 2026,
            month: 8,
            day: 27,
            hour: 19
        ))
    }

    @Test func pendingWorkReminderCrossingIntoIdleIsCancelledAndReplanned() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 18, minute: 30),
            status: .scheduled
        )

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            events: [event],
            now: now
        )

        #expect(plan.eventIDsToCancel == [event.id])
        #expect(plan.reminders.count == 1)
        #expect(plan.reminders.first?.eventID == nil)
        #expect(plan.reminders.first?.candidate.mode == .idle)
        #expect(plan.reminders.first?.candidate.dueAt == Self.date(
            year: 2026,
            month: 8,
            day: 27,
            hour: 19
        ))
    }

    @Test func reminderCompletedBeforeBoundaryStillStartsNextIntervalAcrossModes() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 17, minute: 45),
            status: .acknowledged,
            resolvedAt: Self.date(year: 2026, month: 8, day: 27, hour: 17, minute: 45)
        )

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            events: [event],
            now: Self.date(year: 2026, month: 8, day: 27, hour: 18)
        )

        #expect(plan.reminders.first?.candidate.mode == .idle)
        #expect(plan.reminders.first?.candidate.dueAt == Self.date(
            year: 2026,
            month: 8,
            day: 27,
            hour: 18,
            minute: 45
        ))
    }

    @Test func pendingReminderInsideItsOwnModeIsRetained() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 17, minute: 55),
            status: .scheduled
        )

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [],
            events: [event],
            now: now
        )

        #expect(plan.eventIDsToCancel.isEmpty)
        #expect(plan.reminders == [PlannedReminder(
            eventID: event.id,
            candidate: ReminderCandidate(
                behavior: .hydration,
                mode: .work,
                dueAt: event.timestamp
            )
        )])
    }

    @Test func sleepBoundaryCancelsAwakeReminderAndPlansAfterWakeUp() {
        let sleepNow = Self.date(year: 2026, month: 8, day: 27, hour: 22)
        let event = ReminderEvent(
            behavior: .movement,
            context: .idle,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 23, minute: 30),
            status: .scheduled
        )

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [],
            idleRules: [
                ReminderRule(behavior: .movement, isEnabled: true, frequency: .regular)
            ],
            events: [event],
            now: sleepNow
        )

        #expect(plan.eventIDsToCancel == [event.id])
        #expect(plan.reminders.first?.candidate.mode == .idle)
        #expect(plan.reminders.first?.candidate.dueAt == Self.date(
            year: 2026,
            month: 8,
            day: 28,
            hour: 8
        ))
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static var schedule: DailySchedule {
        DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.thursday]
        )
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        Self.calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
