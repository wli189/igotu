import Foundation
import Testing
@testable import igotu

struct ReminderHistoryStoreTests {
    @Test func scheduledEventsPersistAndRestore() {
        let suiteName = "ReminderHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date()
        let event = ReminderHistoryStore(defaults: defaults).recordScheduled(
            behavior: .hydration,
            context: .work,
            dueAt: now.addingTimeInterval(60 * 60),
            now: now
        )

        let restoredStore = ReminderHistoryStore(defaults: defaults)
        let events = restoredStore.recentEvents(
            since: now.addingTimeInterval(-60),
            now: now
        )

        #expect(events == [event])
        #expect(events.first?.status == .scheduled)
    }

    @Test func acknowledgedEventsAreCountedAsCompleted() {
        let suiteName = "ReminderHistoryCompletionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReminderHistoryStore(defaults: defaults)
        let now = Date()
        let event = store.recordScheduled(
            behavior: .standUp,
            context: .work,
            dueAt: now,
            now: now
        )

        store.updateStatus(for: event.id, to: .acknowledged, at: now)

        #expect(store.completedEvents(on: now).count == 1)
    }

    @Test func cancelledEventsDoNotAffectReminderCooldown() {
        let suiteName = "ReminderHistoryCancellationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReminderHistoryStore(defaults: defaults)
        let now = Date()
        let event = store.recordScheduled(
            behavior: .movement,
            context: .idle,
            dueAt: now,
            now: now
        )

        store.updateStatus(for: event.id, to: .cancelled, at: now)

        #expect(store.recentEvents(since: now.addingTimeInterval(-60), now: now).isEmpty)
    }

    @Test func terminalEventsCannotBeOverwrittenByDelayedCallbacks() {
        let suiteName = "ReminderHistoryTerminalStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReminderHistoryStore(defaults: defaults)
        let now = Date()
        let event = store.recordScheduled(
            behavior: .hydration,
            context: .work,
            dueAt: now,
            now: now
        )

        store.updateStatus(for: event.id, to: .acknowledged, at: now)
        store.updateStatus(for: event.id, to: .delivered, at: now.addingTimeInterval(1))

        #expect(store.events.first?.status == .acknowledged)
    }

    @Test func overdueScheduledEventsExpire() {
        let suiteName = "ReminderHistoryExpirationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReminderHistoryStore(defaults: defaults)
        let now = Date()
        let event = store.recordScheduled(
            behavior: .movement,
            context: .idle,
            dueAt: now.addingTimeInterval(-60),
            now: now.addingTimeInterval(-60)
        )

        store.expireScheduledEvents(before: now)

        #expect(store.events.first?.id == event.id)
        #expect(store.events.first?.status == .expired)
    }

    @Test func scheduledEventsExpireAfterGracePeriod() {
        let suiteName = "ReminderHistoryGracePeriodTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReminderHistoryStore(defaults: defaults)
        let now = Date()
        let event = store.recordScheduled(
            behavior: .hydration,
            context: .work,
            dueAt: now,
            now: now
        )

        store.expireScheduledEvents(
            before: now.addingTimeInterval(29 * 60),
            gracePeriod: 30 * 60
        )
        #expect(store.status(for: event.id) == .scheduled)

        store.expireScheduledEvents(
            before: now.addingTimeInterval(30 * 60),
            gracePeriod: 30 * 60
        )
        #expect(store.status(for: event.id) == .expired)
    }

    @Test func deliveredEventsExpireAfterGracePeriod() {
        let suiteName = "ReminderHistoryDeliveredExpirationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReminderHistoryStore(defaults: defaults)
        let now = Date()
        let event = store.recordScheduled(
            behavior: .standUp,
            context: .work,
            dueAt: now,
            now: now
        )
        store.updateStatus(for: event.id, to: .delivered, at: now)

        store.expireScheduledEvents(
            before: now.addingTimeInterval(30 * 60),
            gracePeriod: 30 * 60
        )

        #expect(store.status(for: event.id) == .expired)
    }
}
