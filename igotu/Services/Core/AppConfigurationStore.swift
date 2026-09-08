//
//  Untitled.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation
import Combine
import IgotuCore

final class AppConfigurationStore: ObservableObject {
    private enum Key {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let schedule = "dailySchedule"
        static let workReminders = "workReminders"
        static let idleReminders = "idleReminders"
        static let dailyGoals = "dailyGoals"
        static let sleepReminderLeadTime = "sleepReminderLeadTime"
    }

    private static let defaultSchedule = DailySchedule(
        sleepPeriods: [],
        workPeriods: []
    )

    private static let defaultWorkReminders = [
        ReminderRule(behavior: .hydration, isEnabled: true, frequency: ReminderFrequency(interval: 60 * 60, offsetRange: -8 * 60 ... 8 * 60)),
        ReminderRule(behavior: .standUp, isEnabled: true, frequency: ReminderFrequency(interval: 30 * 60, offsetRange: -2 * 60 ... 2 * 60)),
        ReminderRule(behavior: .movement, isEnabled: true, frequency: ReminderFrequency(interval: 60 * 60, offsetRange: -8 * 60 ... 8 * 60))
    ]

    private static let defaultIdleReminders = [
        ReminderRule(behavior: .hydration, isEnabled: true, frequency: ReminderFrequency(interval: 2 * 60 * 60, offsetRange: -8 * 60 ... 8 * 60)),
        ReminderRule(behavior: .standUp, isEnabled: true, frequency: ReminderFrequency(interval: 2 * 60 * 60, offsetRange: -8 * 60 ... 8 * 60)),
        ReminderRule(behavior: .movement, isEnabled: true, frequency: ReminderFrequency(interval: 60 * 60, offsetRange: -8 * 60 ... 8 * 60))
    ]

    @Published private(set) var schedule: DailySchedule
    @Published private(set) var workReminders: [ReminderRule]
    @Published private(set) var idleReminders: [ReminderRule]
    @Published private(set) var dailyGoals: DailyGoals
    @Published private(set) var sleepReminderLeadTime: TimeInterval
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
        dailyGoals = Self.loadDailyGoals(from: defaults)
        sleepReminderLeadTime = Self.loadSleepReminderLeadTime(from: defaults)

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

    func save(dailyGoals: DailyGoals) {
        let normalizedGoals = dailyGoals.normalized

        self.dailyGoals = normalizedGoals
        if let data = try? JSONEncoder().encode(normalizedGoals) {
            defaults.set(data, forKey: Key.dailyGoals)
        }
    }

    func save(sleepReminderLeadTime: TimeInterval) {
        let normalizedLeadTime = Self.normalizedSleepReminderLeadTime(
            sleepReminderLeadTime
        )

        self.sleepReminderLeadTime = normalizedLeadTime
        defaults.set(normalizedLeadTime, forKey: Key.sleepReminderLeadTime)
    }

    func reminderRule(for behavior: Behavior, in context: ReminderContext) -> ReminderRule {
        let rules = context == .work ? workReminders : idleReminders
        return rules.first { $0.behavior == behavior }
            ?? Self.defaultReminderRules(for: context).first { $0.behavior == behavior }
            ?? Self.fallbackReminderRule(for: behavior)
    }

    func availableReminderBehaviors(in context: ReminderContext) -> [Behavior] {
        let rules = context == .work ? workReminders : idleReminders
        return Behavior.allCases.filter { behavior in
            !rules.contains { $0.behavior == behavior }
        }
    }

    func addReminder(for behavior: Behavior, in context: ReminderContext) {
        let rules = context == .work ? workReminders : idleReminders
        guard !rules.contains(where: { $0.behavior == behavior }) else { return }

        update(reminderRule(for: behavior, in: context), in: context)
    }

    func removeReminder(for behavior: Behavior, in context: ReminderContext) {
        switch context {
        case .work:
            workReminders.removeAll { $0.behavior == behavior }
            persist(workReminders, forKey: Key.workReminders)
        case .idle:
            idleReminders.removeAll { $0.behavior == behavior }
            persist(idleReminders, forKey: Key.idleReminders)
        }
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
        rule.frequency = frequency.customValue
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

        return normalizedReminderRules(rules)
    }

    private static func loadDailyGoals(from defaults: UserDefaults) -> DailyGoals {
        guard
            let data = defaults.data(forKey: Key.dailyGoals),
            let goals = try? JSONDecoder().decode(DailyGoals.self, from: data)
        else {
            return DailyGoals()
        }

        return goals.normalized
    }

    private static func loadSleepReminderLeadTime(
        from defaults: UserDefaults
    ) -> TimeInterval {
        let storedValue = ((defaults.object(
            forKey: Key.sleepReminderLeadTime
        ) as? NSNumber)?.doubleValue) ?? ReminderTiming.defaultSleepReminderLeadTime

        return normalizedSleepReminderLeadTime(storedValue)
    }

    private static func normalizedSleepReminderLeadTime(
        _ value: TimeInterval
    ) -> TimeInterval {
        let clampedValue = min(
            max(value, ReminderTiming.minimumSleepReminderLeadTime),
            ReminderTiming.maximumSleepReminderLeadTime
        )
        let step = ReminderTiming.sleepReminderLeadTimeStep

        return (clampedValue / step).rounded() * step
    }

    private static func normalizedReminderRules(
        _ rules: [ReminderRule]
    ) -> [ReminderRule] {
        var rulesByBehavior: [Behavior: ReminderRule] = [:]
        for rule in rules {
            rulesByBehavior[rule.behavior] = rule
        }

        var normalizedRules: [ReminderRule] = []
        for rule in rules {
            guard !normalizedRules.contains(where: { $0.behavior == rule.behavior }),
                  let normalizedRule = rulesByBehavior[rule.behavior] else { continue }
            normalizedRules.append(normalizedRule)
        }

        return normalizedRules.map { rule in
            var customRule = rule
            customRule.isEnabled = true
            customRule.frequency = rule.frequency.customValue
            return customRule
        }
    }

    private static func defaultReminderRules(
        for context: ReminderContext
    ) -> [ReminderRule] {
        context == .work ? defaultWorkReminders : defaultIdleReminders
    }

    private static func fallbackReminderRule(for behavior: Behavior) -> ReminderRule {
        ReminderRule(
            behavior: behavior,
            isEnabled: true,
            frequency: ReminderFrequency(interval: 60 * 60, offsetRange: -8 * 60 ... 8 * 60)
        )
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
