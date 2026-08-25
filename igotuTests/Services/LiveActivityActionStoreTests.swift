import Foundation
import Testing
@testable import igotu

struct LiveActivityActionStoreTests {
    @Test func actionsArePersistedAndConsumedOnce() {
        let suiteName = "LiveActivityActionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let eventID = UUID()
        let date = Date()
        let action = LiveActivityAction(
            eventID: eventID,
            status: .acknowledged,
            date: date
        )

        LiveActivityActionStore.record(
            eventID: eventID,
            status: .acknowledged,
            date: date,
            defaults: defaults
        )

        #expect(LiveActivityActionStore.consume(defaults: defaults) == [action])
        #expect(LiveActivityActionStore.consume(defaults: defaults).isEmpty)
    }
}
