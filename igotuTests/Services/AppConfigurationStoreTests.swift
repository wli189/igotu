import Foundation
import Testing
@testable import igotu

struct AppConfigurationStoreTests {
    private struct LegacySchedule: Encodable {
        let sleepStart: DateComponents
        let sleepEnd: DateComponents
        let workStart: DateComponents
        let workEnd: DateComponents
        let workdays: Set<Weekday>
    }

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

    @Test func startsWithAnEmptyScheduleBeforeSetup() {
        let suiteName = "EmptyScheduleDefaultsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppConfigurationStore(defaults: defaults)

        #expect(!store.hasCompletedSetup)
        #expect(store.schedule.sleepPeriods.isEmpty)
        #expect(store.schedule.workPeriods.isEmpty)
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

    @Test func migratesLegacyScheduleIntoPeriodRules() throws {
        let suiteName = "LegacyScheduleMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let legacySchedule = LegacySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 18),
            workdays: [.monday, .wednesday]
        )
        defaults.set(
            try JSONEncoder().encode(legacySchedule),
            forKey: "dailySchedule"
        )

        let store = AppConfigurationStore(defaults: defaults)

        #expect(store.schedule.sleepPeriods.count == 1)
        #expect(store.schedule.sleepPeriods[0].days == Set(Weekday.allCases))
        #expect(store.schedule.workPeriods.count == 1)
        #expect(store.schedule.workPeriods[0].days == [.monday, .wednesday])
        #expect(store.schedule.workPeriods[0].start.hour == 9)
    }

    @Test func restoresDailyGoals() {
        let suiteName = "DailyGoalsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = AppConfigurationStore(defaults: defaults)
        firstStore.save(dailyGoals: DailyGoals(hydrationCount: 10, standingHours: 12))

        let restoredStore = AppConfigurationStore(defaults: defaults)

        #expect(restoredStore.dailyGoals == DailyGoals(hydrationCount: 10, standingHours: 12))
    }

    @Test func restoresCustomSleepReminderLeadTime() {
        let suiteName = "SleepReminderLeadTimeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstStore = AppConfigurationStore(defaults: defaults)
        firstStore.save(sleepReminderLeadTime: 45 * 60)

        let restoredStore = AppConfigurationStore(defaults: defaults)

        #expect(restoredStore.sleepReminderLeadTime == 45 * 60)
    }

    @Test func clampsSleepReminderLeadTimeToSupportedRange() {
        let suiteName = "SleepReminderLeadTimeNormalizationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppConfigurationStore(defaults: defaults)
        store.save(sleepReminderLeadTime: 0)
        #expect(store.sleepReminderLeadTime == 15 * 60)

        store.save(sleepReminderLeadTime: 180 * 60)
        #expect(store.sleepReminderLeadTime == 120 * 60)
    }

    @Test func normalizesSavedDailyGoalsOnLoad() throws {
        let suiteName = "DailyGoalsNormalizationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let data = try JSONEncoder().encode(
            DailyGoals(hydrationCount: 99, standingHours: -10)
        )
        defaults.set(data, forKey: "dailyGoals")

        let store = AppConfigurationStore(defaults: defaults)

        #expect(store.dailyGoals == DailyGoals(hydrationCount: 20, standingHours: 1))
    }

    @Test func fillsMissingRulesAndKeepsLastDuplicate() throws {
        let suiteName = "ReminderRulesNormalizationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let savedRules = [
            ReminderRule(behavior: .hydration, isEnabled: false, frequency: .frequent),
            ReminderRule(behavior: .hydration, isEnabled: true, frequency: .occasional)
        ]
        defaults.set(
            try JSONEncoder().encode(savedRules),
            forKey: "workReminders"
        )

        let store = AppConfigurationStore(defaults: defaults)

        #expect(store.workReminders.map(\.behavior) == Behavior.allCases)
        #expect(store.reminderRule(for: .hydration, in: .work).isEnabled)
        #expect(
            store.reminderRule(for: .hydration, in: .work).frequency == .occasional
        )
        #expect(
            store.reminderRule(for: .standUp, in: .work).frequency == .frequent
        )
        #expect(store.reminderRule(for: .movement, in: .work).isEnabled)
    }
}
