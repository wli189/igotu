import Foundation
import IgotuCore

@MainActor
enum PreviewSupport {
    static let emptySchedule = DailySchedule(
        sleepPeriods: [],
        workPeriods: []
    )

    static let sampleSchedule = DailySchedule(
        sleepPeriods: [
            DailySchedulePeriod(
                start: DateComponents(hour: 23),
                end: DateComponents(hour: 7),
                days: Set(Weekday.allCases)
            )
        ],
        workPeriods: [
            DailySchedulePeriod(
                start: DateComponents(hour: 9),
                end: DateComponents(hour: 17, minute: 30),
                days: Weekday.defaultWorkdays
            )
        ]
    )

    static let allDayWorkSchedule = DailySchedule(
        sleepPeriods: [],
        workPeriods: [
            DailySchedulePeriod(
                start: DateComponents(hour: 0),
                end: DateComponents(hour: 23, minute: 59),
                days: Set(Weekday.allCases)
            )
        ]
    )

    static let allDaySleepSchedule = DailySchedule(
        sleepPeriods: [
            DailySchedulePeriod(
                start: DateComponents(hour: 0),
                end: DateComponents(hour: 23, minute: 59),
                days: Set(Weekday.allCases)
            )
        ],
        workPeriods: []
    )

    static func configuration(
        named name: String,
        schedule: DailySchedule? = nil,
        workReminders: [ReminderRule]? = nil,
        idleReminders: [ReminderRule]? = nil
    ) -> AppConfigurationStore {
        let store = AppConfigurationStore(defaults: defaults(named: "configuration.\(name)"))

        if let schedule {
            store.save(schedule: schedule)
        }
        if let workReminders {
            replaceReminders(workReminders, in: .work, store: store)
        }
        if let idleReminders {
            replaceReminders(idleReminders, in: .idle, store: store)
        }

        return store
    }

    static func history(named name: String) -> ReminderHistoryStore {
        ReminderHistoryStore(defaults: defaults(named: "history.\(name)"))
    }

    static func reminderCoordinator(
        configuration: AppConfigurationStore,
        history: ReminderHistoryStore
    ) -> ReminderCoordinator {
        ReminderCoordinator(
            configuration: configuration,
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            history: history,
            notificationScheduler: NotificationScheduler()
        )
    }

    private static func defaults(named name: String) -> UserDefaults {
        let suiteName = "com.brian.igotu.preview.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func replaceReminders(
        _ rules: [ReminderRule],
        in context: ReminderContext,
        store: AppConfigurationStore
    ) {
        for behavior in Behavior.allCases {
            store.removeReminder(for: behavior, in: context)
        }

        for rule in rules {
            store.addReminder(for: rule.behavior, in: context)
            store.setReminderFrequency(
                rule.frequency,
                for: rule.behavior,
                in: context
            )
        }
    }
}
