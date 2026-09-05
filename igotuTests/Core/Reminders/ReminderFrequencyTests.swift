import Foundation
import Testing
import IgotuCore

struct ReminderFrequencyTests {
    @Test func sharedFrequencyOptionsIncludeCustomIntervalsAndOffsetTiers() {
        let customInterval = 75 * 60.0

        #expect(ReminderFrequency.intervalOptions(including: customInterval).contains(customInterval))
        #expect(ReminderFrequency.offsetTierMinutes(for: customInterval) == [0, 5, 10, 15])
        #expect(ReminderFrequency.nearestOffsetMinutes(to: 12, for: customInterval) == 10)
        #expect(ReminderFrequency.nearestOffsetMinutes(to: 7, for: ReminderFrequency.regular.interval) == 8)
    }

    @Test func presetValuesCanBeMigratedToCustomFrequencies() {
        #expect(ReminderFrequency.regular.customValue.isCustom)
        #expect(ReminderFrequency.regular.customValue.interval == ReminderFrequency.regular.interval)
        #expect(ReminderFrequency.regular.customValue.offsetRange == ReminderFrequency.regular.offsetRange)
    }
}
