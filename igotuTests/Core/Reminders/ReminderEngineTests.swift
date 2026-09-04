import Foundation
import Testing
import IgotuCore
@testable import igotu

struct ReminderEngineTests {
    private let engine = ReminderEngine(offsetProvider: { _ in 0 })
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func frequencyIntervalsMatchProductDefaults() {
        #expect(ReminderFrequency.occasional.interval == 2 * 60 * 60)
        #expect(ReminderFrequency.regular.interval == 60 * 60)
        #expect(ReminderFrequency.frequent.interval == 30 * 60)
    }

    @Test func maximumOffsetScalesWithInterval() {
        #expect(ReminderFrequency.maximumOffsetMinutes(for: 15 * 60) == 3)
        #expect(ReminderFrequency.maximumOffsetMinutes(for: 30 * 60) == 6)
        #expect(ReminderFrequency.maximumOffsetMinutes(for: 60 * 60) == 12)
    }

    @Test func customFrequencyUsesItsIntervalAndOffsetRange() throws {
        let frequency = ReminderFrequency(
            interval: 45 * 60,
            offsetRange: -5 * 60 ... 10 * 60
        )
        let engine = ReminderEngine(offsetProvider: { frequency in
            #expect(frequency == ReminderFrequency(
                interval: 45 * 60,
                offsetRange: -5 * 60 ... 10 * 60
            ))
            return 10 * 60
        })

        let result = try #require(engine.nextReminder(from: input(rules: [
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: frequency)
        ])))

        #expect(result.dueAt == now.addingTimeInterval(55 * 60))
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

    @Test func cancelledEventsDoNotDelayTheNextReminder() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: now.addingTimeInterval(-10 * 60),
            status: .cancelled
        )

        let result = engine.nextReminder(from: input(
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [event]
        ))

        #expect(result?.dueAt == now.addingTimeInterval(60 * 60))
    }

    @Test func futureScheduledEventsDoNotDelayTheNextReminder() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: now.addingTimeInterval(30 * 60),
            status: .scheduled
        )

        let result = engine.nextReminder(from: input(
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [event]
        ))

        #expect(result?.dueAt == now.addingTimeInterval(60 * 60))
    }

    @Test func reminderAfterActiveIntervalIsNotScheduled() {
        let interval = DailyScheduleInterval(
            mode: .work,
            start: now.addingTimeInterval(-10 * 60),
            end: now.addingTimeInterval(45 * 60)
        )

        let result = engine.nextReminder(from: input(
            activeInterval: interval,
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ]
        ))

        #expect(result == nil)
    }

    @Test func acknowledgedEventUsesItsCompletionTime() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: now.addingTimeInterval(-30 * 60),
            status: .acknowledged,
            resolvedAt: now.addingTimeInterval(-10 * 60)
        )

        let result = engine.nextReminder(from: input(
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [event]
        ))

        #expect(result?.dueAt == now.addingTimeInterval(50 * 60))
    }

    @Test func skippedEventUsesTheTimeItWasSkipped() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: now.addingTimeInterval(-15 * 60),
            status: .skipped,
            resolvedAt: now.addingTimeInterval(-5 * 60)
        )

        let result = engine.nextReminder(from: input(
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [event]
        ))

        #expect(result?.dueAt == now.addingTimeInterval(55 * 60))
    }

    @Test func expiredEventUsesItsDueTimePlusTheGracePeriod() {
        let event = ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: now.addingTimeInterval(-30 * 60),
            status: .expired,
            resolvedAt: now
        )

        let result = engine.nextReminder(from: input(
            rules: [
                ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
            ],
            recentEvents: [event]
        ))

        #expect(result?.dueAt == now.addingTimeInterval(45 * 60))
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

    @Test func enabledRulesProduceOneCandidatePerBehavior() {
        let result = engine.nextReminders(from: input(rules: [
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular),
            ReminderRule(behavior: .standUp, isEnabled: true, frequency: .regular),
            ReminderRule(behavior: .movement, isEnabled: true, frequency: .regular)
        ]))

        #expect(result.map(\.behavior) == [.standUp, .hydration, .movement])
    }

    private func input(
        mode: DailyMode = .work,
        activeInterval: DailyScheduleInterval? = nil,
        rules: [ReminderRule] = [
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular)
        ],
        recentEvents: [ReminderEvent] = []
    ) -> ReminderEngineInput {
        ReminderEngineInput(
            now: now,
            mode: mode,
            rules: rules,
            recentEvents: recentEvents,
            activeInterval: activeInterval
        )
    }
}
