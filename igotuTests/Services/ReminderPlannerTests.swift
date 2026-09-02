import Foundation
import Testing
@testable import igotu

struct ReminderPlannerTests {
    private let planner = ReminderPlanner(
        engine: ReminderEngine(offsetProvider: { _ in 0 }),
        timeline: DailyScheduleTimeline(calendar: Self.calendar),
        planningHorizon: 2 * 60 * 60
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

    @Test func plansMultipleRemindersWithinThePlanningHorizon() {
        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [],
            events: [],
            now: Self.date(year: 2026, month: 8, day: 27, hour: 10)
        )

        #expect(plan.reminders.map(\.candidate.dueAt) == [
            Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 30),
            Self.date(year: 2026, month: 8, day: 27, hour: 11),
            Self.date(year: 2026, month: 8, day: 27, hour: 11, minute: 30)
        ])
    }

    @Test func keepsExistingEventsAndPlansTheRemainingWindow() {
        let existingEvent = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 30),
            status: .scheduled
        )

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [],
            events: [existingEvent],
            now: Self.date(year: 2026, month: 8, day: 27, hour: 10)
        )

        #expect(plan.eventIDsToCancel.isEmpty)
        #expect(plan.reminders.map(\.candidate.dueAt) == [
            existingEvent.timestamp,
            Self.date(year: 2026, month: 8, day: 27, hour: 11),
            Self.date(year: 2026, month: 8, day: 27, hour: 11, minute: 30)
        ])
        #expect(plan.reminders.first?.eventID == existingEvent.id)
    }

    @Test func rollingPlanStartsFromCompletionTimeAndCancelsFutureEvents() {
        let oldFutureEvent = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 28),
            status: .scheduled
        )
        let completionTime = Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 5)
        let completedEvent = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 10),
            status: .acknowledged,
            resolvedAt: completionTime
        )

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [],
            events: [completedEvent, oldFutureEvent],
            now: completionTime,
            rollingFrom: completionTime
        )

        #expect(plan.eventIDsToCancel == [oldFutureEvent.id])
        #expect(plan.reminders.map(\.candidate.dueAt) == [
            Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 35),
            Self.date(year: 2026, month: 8, day: 27, hour: 11, minute: 5),
            Self.date(year: 2026, month: 8, day: 27, hour: 11, minute: 35)
        ])
        #expect(plan.reminders.allSatisfy { $0.eventID == nil })
    }

    @Test func rollingPlanCanReplanOnlyTheAffectedBehavior() {
        let hydrationEvent = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 28),
            status: .scheduled
        )
        let movementEvent = ReminderEvent(
            behavior: .movement,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 50),
            status: .scheduled
        )
        let completionTime = Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 5)

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent),
                ReminderRule(behavior: .movement, isEnabled: true, frequency: .regular)
            ],
            idleRules: [],
            events: [hydrationEvent, movementEvent],
            now: completionTime,
            rollingFrom: completionTime,
            rollingBehaviors: [.hydration]
        )

        #expect(plan.eventIDsToCancel == [hydrationEvent.id])
        #expect(plan.reminders.contains {
            $0.eventID == movementEvent.id
                && $0.candidate.dueAt == movementEvent.timestamp
        })
        #expect(plan.reminders.filter {
            $0.candidate.behavior == .movement
        }.count == 1)
    }

    @Test func compensationBecomesTheFirstReminderOfTheNewWindow() {
        let skipTime = Self.date(year: 2026, month: 8, day: 27, hour: 10, minute: 5)
        let compensationTime = skipTime.addingTimeInterval(9 * 60)
        let skippedEvent = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 10),
            status: .skipped,
            resolvedAt: skipTime
        )

        let plan = planner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [],
            events: [skippedEvent],
            now: skipTime,
            rollingFrom: compensationTime,
            compensationCandidates: [ReminderCandidate(
                behavior: .hydration,
                mode: .work,
                dueAt: compensationTime
            )]
        )

        #expect(plan.reminders.map(\.candidate.dueAt) == [
            compensationTime,
            compensationTime.addingTimeInterval(30 * 60),
            compensationTime.addingTimeInterval(60 * 60),
            compensationTime.addingTimeInterval(90 * 60)
        ])
    }

    @Test func capsThePlannedReminderCount() {
        let cappedPlanner = ReminderPlanner(
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            timeline: DailyScheduleTimeline(calendar: Self.calendar),
            planningHorizon: 12 * 60 * 60,
            maximumReminderCount: 2
        )

        let plan = cappedPlanner.plan(
            for: Self.schedule,
            workRules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
            ],
            idleRules: [],
            events: [],
            now: Self.date(year: 2026, month: 8, day: 27, hour: 10)
        )

        #expect(plan.reminders.count == 2)
    }

    @Test func sleepBoundaryCancelsAwakeReminderAndPlansAfterWakeUp() {
        let sleepNow = Self.date(year: 2026, month: 8, day: 27, hour: 22)
        let longHorizonPlanner = ReminderPlanner(
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            timeline: DailyScheduleTimeline(calendar: Self.calendar),
            planningHorizon: 12 * 60 * 60
        )
        let event = ReminderEvent(
            behavior: .movement,
            context: .idle,
            timestamp: Self.date(year: 2026, month: 8, day: 27, hour: 23, minute: 30),
            status: .scheduled
        )

        let plan = longHorizonPlanner.plan(
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
