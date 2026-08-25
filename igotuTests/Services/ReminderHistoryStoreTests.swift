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
}
