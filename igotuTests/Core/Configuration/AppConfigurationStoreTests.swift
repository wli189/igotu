import Foundation
import Testing
import IgotuCore
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

    @Test func defaultReminderOffsetsAreAvailablePickerOptions() {
        let suiteName = "DefaultReminderOffsetTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppConfigurationStore(defaults: defaults)

        #expect(store.reminderRule(for: .hydration, in: .work).frequency.offsetRange == -8 * 60 ... 8 * 60)
        #expect(store.reminderRule(for: .standUp, in: .work).frequency.offsetRange == -2 * 60 ... 2 * 60)
        #expect(store.reminderRule(for: .movement, in: .work).frequency.offsetRange == -8 * 60 ... 8 * 60)
    }

    @Test func restoresReminderRulesIndependentlyForWorkAndIdle() {
        let suiteName = "ReminderRulesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstStore = AppConfigurationStore(defaults: defaults)
        firstStore.removeReminder(for: .hydration, in: .work)
        firstStore.setReminderFrequency(.frequent, for: .movement, in: .idle)

        let restoredStore = AppConfigurationStore(defaults: defaults)

        #expect(restoredStore.availableReminderBehaviors(in: .work).contains(.hydration))
        #expect(restoredStore.reminderRule(for: .hydration, in: .idle).isEnabled)
        #expect(restoredStore.reminderRule(for: .movement, in: .idle).frequency.isCustom)
        #expect(restoredStore.reminderRule(for: .movement, in: .idle).frequency.interval == ReminderFrequency.frequent.interval)
        #expect(restoredStore.reminderRule(for: .movement, in: .work).frequency.isCustom)
        #expect(restoredStore.reminderRule(for: .movement, in: .work).frequency.interval == ReminderFrequency.regular.interval)
    }

    @Test func normalizesDisabledSavedRuleAsAnEnabledMember() throws {
        let suiteName = "DisabledReminderMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let savedRules = [
            ReminderRule(behavior: .hydration, isEnabled: false, frequency: .frequent)
        ]
        defaults.set(try JSONEncoder().encode(savedRules), forKey: "workReminders")

        let store = AppConfigurationStore(defaults: defaults)

        #expect(store.workReminders.map(\.behavior) == [.hydration])
        #expect(store.reminderRule(for: .hydration, in: .work).isEnabled)
    }

    @Test func restoresCustomFrequencySettings() {
        let suiteName = "CustomFrequencyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = AppConfigurationStore(defaults: defaults)
        firstStore.setReminderFrequency(
            ReminderFrequency(
                interval: 45 * 60,
                offsetRange: -5 * 60 ... 10 * 60
            ),
            for: .hydration,
            in: .work
        )

        let restoredStore = AppConfigurationStore(defaults: defaults)
        let frequency = restoredStore.reminderRule(
            for: .hydration,
            in: .work
        ).frequency

        #expect(frequency.isCustom)
        #expect(frequency.interval == 45 * 60)
        #expect(frequency.offsetRange == -5 * 60 ... 10 * 60)
    }

    @Test func decodesFrequencyPresetsSavedByThePreviousModel() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            [
                "behavior": "hydration",
                "isEnabled": true,
                "frequency": "regular"
            ]
        ])

        let rules = try JSONDecoder().decode([ReminderRule].self, from: data)

        #expect(rules.first?.frequency == .regular)
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

    @Test func preservesSavedReminderMembershipAndKeepsLastDuplicate() throws {
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

        #expect(store.workReminders.map(\.behavior) == [.hydration])
        #expect(store.reminderRule(for: .hydration, in: .work).isEnabled)
        #expect(store.reminderRule(for: .hydration, in: .work).frequency.isCustom)
        #expect(store.reminderRule(for: .hydration, in: .work).frequency.interval == ReminderFrequency.occasional.interval)
        #expect(store.reminderRule(for: .standUp, in: .work).frequency.isCustom)
        #expect(store.reminderRule(for: .standUp, in: .work).frequency.interval == ReminderFrequency.frequent.interval)
        #expect(store.reminderRule(for: .movement, in: .work).frequency.isCustom)
    }

    @Test func remindersCanBeAddedAndRemovedPerContext() throws {
        let suiteName = "ReminderMembershipTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(try JSONEncoder().encode([ReminderRule]()), forKey: "workReminders")
        defaults.set(try JSONEncoder().encode([ReminderRule]()), forKey: "idleReminders")

        let store = AppConfigurationStore(defaults: defaults)
        #expect(store.workReminders.isEmpty)
        #expect(store.idleReminders.isEmpty)

        store.addReminder(for: .hydration, in: .work)
        #expect(store.workReminders.map(\.behavior) == [.hydration])
        #expect(!store.availableReminderBehaviors(in: .work).contains(.hydration))
        #expect(store.availableReminderBehaviors(in: .idle).contains(.hydration))

        store.removeReminder(for: .hydration, in: .work)
        #expect(store.workReminders.isEmpty)
        #expect(store.availableReminderBehaviors(in: .work).contains(.hydration))

        let restoredStore = AppConfigurationStore(defaults: defaults)
        #expect(restoredStore.workReminders.isEmpty)
        #expect(restoredStore.idleReminders.isEmpty)
    }
}
