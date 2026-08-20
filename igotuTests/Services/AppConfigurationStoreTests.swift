import Foundation
import Testing
@testable import igotu

struct AppConfigurationStoreTests {
    @Test func restoresSavedScheduleAfterRecreatingStore() {
        let suiteName = "AppConfigurationStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 22, minute: 30),
            sleepEnd: DateComponents(hour: 6, minute: 45),
            workStart: DateComponents(hour: 8, minute: 15),
            workEnd: DateComponents(hour: 17, minute: 30)
        )

        let firstStore = AppConfigurationStore(defaults: defaults)
        #expect(!firstStore.hasCompletedSetup)
        firstStore.save(schedule: schedule)

        let restoredStore = AppConfigurationStore(defaults: defaults)

        #expect(restoredStore.hasCompletedSetup)
        #expect(restoredStore.schedule.sleepStart.hour == 22)
        #expect(restoredStore.schedule.sleepStart.minute == 30)
        #expect(restoredStore.schedule.sleepEnd.hour == 6)
        #expect(restoredStore.schedule.sleepEnd.minute == 45)
        #expect(restoredStore.schedule.workStart.hour == 8)
        #expect(restoredStore.schedule.workStart.minute == 15)
        #expect(restoredStore.schedule.workEnd.hour == 17)
        #expect(restoredStore.schedule.workEnd.minute == 30)
    }

    @Test func restoresReminderRulesIndependentlyForWorkAndIdle() {
        let suiteName = "ReminderRulesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstStore = AppConfigurationStore(defaults: defaults)
        firstStore.setReminderEnabled(false, for: .hydration, in: .work)
        firstStore.setReminderFrequency(.frequent, for: .movement, in: .idle)

        let restoredStore = AppConfigurationStore(defaults: defaults)

        #expect(!restoredStore.reminderRule(for: .hydration, in: .work).isEnabled)
        #expect(restoredStore.reminderRule(for: .hydration, in: .idle).isEnabled)
        #expect(restoredStore.reminderRule(for: .movement, in: .idle).frequency == .frequent)
        #expect(restoredStore.reminderRule(for: .movement, in: .work).frequency == .regular)
    }
}
