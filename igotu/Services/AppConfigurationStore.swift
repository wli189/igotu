//
//  Untitled.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation
import Combine

final class AppConfigurationStore: ObservableObject {
    private enum Key {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let schedule = "dailySchedule"
        static let workReminders = "workReminders"
        static let idleReminders = "idleReminders"
    }

    private static let defaultSchedule = DailySchedule(
        sleepStart: DateComponents(hour: 23),
        sleepEnd: DateComponents(hour: 7),
        workStart: DateComponents(hour: 9),
        workEnd: DateComponents(hour: 18),
        workdays: Weekday.defaultWorkdays
    )

    private static let defaultWorkReminders = [
        ReminderRule(behavior: .hydration, isEnabled: true, frequency: .regular),
        ReminderRule(behavior: .standUp, isEnabled: true, frequency: .frequent),
        ReminderRule(behavior: .movement, isEnabled: true, frequency: .regular)
    ]

    private static let defaultIdleReminders = [
        ReminderRule(behavior: .hydration, isEnabled: true, frequency: .occasional),
        ReminderRule(behavior: .standUp, isEnabled: true, frequency: .occasional),
        ReminderRule(behavior: .movement, isEnabled: true, frequency: .regular)
    ]

    @Published private(set) var schedule: DailySchedule
    @Published private(set) var workReminders: [ReminderRule]
    @Published private(set) var idleReminders: [ReminderRule]
    @Published private(set) var hasCompletedSetup: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        workReminders = Self.loadReminderRules(
            from: defaults,
            key: Key.workReminders,
            defaultValue: Self.defaultWorkReminders
        )
        idleReminders = Self.loadReminderRules(
            from: defaults,
            key: Key.idleReminders,
            defaultValue: Self.defaultIdleReminders
        )

        guard
            let data = defaults.data(forKey: Key.schedule),
            let savedSchedule = try? JSONDecoder().decode(DailySchedule.self, from: data)
        else {
            schedule = Self.defaultSchedule
            hasCompletedSetup = false
            return
        }

        schedule = savedSchedule
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
    }

    func save(schedule: DailySchedule) {
        self.schedule = schedule
        hasCompletedSetup = true

        if let data = try? JSONEncoder().encode(schedule) {
            defaults.set(data, forKey: Key.schedule)
        }

        defaults.set(true, forKey: Key.hasCompletedSetup)
    }

    func reminderRule(for behavior: Behavior, in context: ReminderContext) -> ReminderRule {
        let rules = context == .work ? workReminders : idleReminders
        return rules.first { $0.behavior == behavior }
            ?? ReminderRule(behavior: behavior, isEnabled: false, frequency: .regular)
    }

    func setReminderEnabled(
        _ isEnabled: Bool,
        for behavior: Behavior,
        in context: ReminderContext
    ) {
        var rule = reminderRule(for: behavior, in: context)
        rule.isEnabled = isEnabled
        update(rule, in: context)
    }

    func setReminderFrequency(
        _ frequency: ReminderFrequency,
        for behavior: Behavior,
        in context: ReminderContext
    ) {
        var rule = reminderRule(for: behavior, in: context)
        rule.frequency = frequency
        update(rule, in: context)
    }

    private static func loadReminderRules(
        from defaults: UserDefaults,
        key: String,
        defaultValue: [ReminderRule]
    ) -> [ReminderRule] {
        guard
            let data = defaults.data(forKey: key),
            let rules = try? JSONDecoder().decode([ReminderRule].self, from: data)
        else {
            return defaultValue
        }

        return rules
    }

    private func update(_ rule: ReminderRule, in context: ReminderContext) {
        switch context {
        case .work:
            Self.update(&workReminders, with: rule)
            persist(workReminders, forKey: Key.workReminders)
        case .idle:
            Self.update(&idleReminders, with: rule)
            persist(idleReminders, forKey: Key.idleReminders)
        }
    }

    private static func update(_ rules: inout [ReminderRule], with rule: ReminderRule) {
        if let index = rules.firstIndex(where: { $0.behavior == rule.behavior }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    private func persist(_ rules: [ReminderRule], forKey key: String) {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: key)
        }
    }
}
