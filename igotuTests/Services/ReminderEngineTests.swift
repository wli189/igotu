import Foundation
import Testing
@testable import igotu

struct ReminderEngineTests {
    private let engine = ReminderEngine(offsetProvider: { _ in 0 })
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func frequencyIntervalsMatchProductDefaults() {
        #expect(ReminderFrequency.occasional.interval == 2 * 60 * 60)
        #expect(ReminderFrequency.regular.interval == 60 * 60)
        #expect(ReminderFrequency.frequent.interval == 30 * 60)
    }

    @Test func sleepingModeDoesNotProduceReminder() {
        let result = engine.nextReminder(from: input(mode: .sleeping))

        #expect(result == nil)
    }

    @Test func disabledRulesAreIgnored() {
        let result = engine.nextReminder(from: input(rules: [
            ReminderRule(behavior: .hydration, isEnabled: false, frequency: .frequent)
        ]))

        #expect(result == nil)
    }

    @Test func firstReminderIsScheduledAfterItsFrequencyInterval() {
        let result = engine.nextReminder(from: input(rules: [
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
        ]))

        #expect(result?.behavior == .hydration)
        #expect(result?.dueAt == now.addingTimeInterval(60 * 60))
    }

    @Test func overdueReminderIsReturnedImmediately() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: now.addingTimeInterval(-2 * 60 * 60)
        )

        let result = engine.nextReminder(from: input(
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [event]
        ))

        #expect(result?.dueAt == now)
    }

    @Test func offsetIsAppliedToTheNextReminder() {
        let engine = ReminderEngine(offsetProvider: { _ in 5 * 60 })

        let result = engine.nextReminder(from: input(rules: [
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
        ]))

        #expect(result?.dueAt == now.addingTimeInterval(65 * 60))
    }

    @Test func negativeOffsetCannotScheduleInThePast() {
        let engine = ReminderEngine(offsetProvider: { _ in -20 * 60 })

        let result = engine.nextReminder(from: input(rules: [
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: .frequent)
        ]))

        #expect(result?.dueAt == now.addingTimeInterval(10 * 60))
    }

    @Test func simultaneousRemindersUseStablePriority() {
        let events = [
            ReminderEvent(
                behavior: .movement,
                context: .work,
                timestamp: now.addingTimeInterval(-2 * 60 * 60)
            ),
            ReminderEvent(
                behavior: .hydration,
                context: .work,
                timestamp: now.addingTimeInterval(-2 * 60 * 60)
            ),
            ReminderEvent(
                behavior: .standUp,
                context: .work,
                timestamp: now.addingTimeInterval(-2 * 60 * 60)
            )
        ]

        let result = engine.nextReminder(from: input(
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular),
                ReminderRule(behavior: .standUp, isEnabled: true, frequency: .regular),
                ReminderRule(behavior: .movement, isEnabled: true, frequency: .regular)
            ],
            recentEvents: events
        ))

        #expect(result?.behavior == .standUp)
    }

    private func input(
        mode: DailyMode = .work,
        rules: [ReminderRule] = [
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
        ],
        recentEvents: [ReminderEvent] = []
    ) -> ReminderEngineInput {
        ReminderEngineInput(
            now: now,
            mode: mode,
            rules: rules,
            recentEvents: recentEvents
        )
    }
}
