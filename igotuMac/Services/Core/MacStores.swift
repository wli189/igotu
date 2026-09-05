import Foundation
import Combine
import IgotuCore

@MainActor
final class MacConfigurationStore: ObservableObject {
    private enum Key {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let schedule = "dailySchedule"
        static let workReminders = "workReminders"
        static let idleReminders = "idleReminders"
        static let dailyGoals = "dailyGoals"
        static let sleepReminderLeadTime = "sleepReminderLeadTime"
    }

    private static let defaultSchedule = DailySchedule(sleepPeriods: [], workPeriods: [])
    private static let defaultWorkReminders = Behavior.allCases.map {
        ReminderRule(
            behavior: $0,
            isEnabled: true,
            frequency: $0 == .standUp
                ? ReminderFrequency(interval: 30 * 60, offsetRange: -2 * 60 ... 2 * 60)
                : ReminderFrequency(interval: 60 * 60, offsetRange: -8 * 60 ... 8 * 60)
        )
    }
    private static let defaultIdleReminders = Behavior.allCases.map {
        ReminderRule(
            behavior: $0,
            isEnabled: true,
            frequency: $0 == .movement
                ? ReminderFrequency(interval: 60 * 60, offsetRange: -8 * 60 ... 8 * 60)
                : ReminderFrequency(interval: 2 * 60 * 60, offsetRange: -8 * 60 ... 8 * 60)
        )
    }

    @Published private(set) var schedule: DailySchedule
    @Published private(set) var workReminders: [ReminderRule]
    @Published private(set) var idleReminders: [ReminderRule]
    @Published private(set) var dailyGoals: DailyGoals
    @Published private(set) var sleepReminderLeadTime: TimeInterval
    @Published private(set) var hasCompletedSetup: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        schedule = Self.decode(DailySchedule.self, from: defaults, key: Key.schedule) ?? Self.defaultSchedule
        dailyGoals = (Self.decode(DailyGoals.self, from: defaults, key: Key.dailyGoals) ?? DailyGoals()).normalized
        workReminders = Self.loadRules(from: defaults, key: Key.workReminders, fallback: Self.defaultWorkReminders)
        idleReminders = Self.loadRules(from: defaults, key: Key.idleReminders, fallback: Self.defaultIdleReminders)
        sleepReminderLeadTime = Self.loadLeadTime(from: defaults)
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
    }

    static func preview() -> MacConfigurationStore {
        let suiteName = "igotu.mac.preview"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let schedule = DailySchedule(
            sleepStart: DateComponents(hour: 23),
            sleepEnd: DateComponents(hour: 7),
            workStart: DateComponents(hour: 9),
            workEnd: DateComponents(hour: 17)
        )
        if let data = try? JSONEncoder().encode(schedule) {
            defaults.set(data, forKey: Key.schedule)
        }
        return MacConfigurationStore(defaults: defaults)
    }

    func save(schedule: DailySchedule) {
        self.schedule = schedule
        persist(schedule, key: Key.schedule)
        defaults.set(true, forKey: Key.hasCompletedSetup)
    }

    func save(dailyGoals: DailyGoals) {
        self.dailyGoals = dailyGoals.normalized
        persist(self.dailyGoals, key: Key.dailyGoals)
    }

    func save(sleepReminderLeadTime: TimeInterval) {
        let clamped = min(max(sleepReminderLeadTime, ReminderTiming.minimumSleepReminderLeadTime), ReminderTiming.maximumSleepReminderLeadTime)
        self.sleepReminderLeadTime = (clamped / ReminderTiming.sleepReminderLeadTimeStep).rounded() * ReminderTiming.sleepReminderLeadTimeStep
        defaults.set(self.sleepReminderLeadTime, forKey: Key.sleepReminderLeadTime)
    }

    func reminderRule(for behavior: Behavior, in context: ReminderContext) -> ReminderRule {
        let rules = context == .work ? workReminders : idleReminders
        return rules.first { $0.behavior == behavior } ?? ReminderRule(
            behavior: behavior,
            isEnabled: false,
            frequency: ReminderFrequency(interval: 60 * 60, offsetRange: -8 * 60 ... 8 * 60)
        )
    }

    func setReminderEnabled(_ enabled: Bool, for behavior: Behavior, in context: ReminderContext) {
        var rule = reminderRule(for: behavior, in: context)
        rule.isEnabled = enabled
        update(rule, in: context)
    }

    func setReminderFrequency(_ frequency: ReminderFrequency, for behavior: Behavior, in context: ReminderContext) {
        var rule = reminderRule(for: behavior, in: context)
        rule.frequency = frequency.customValue
        update(rule, in: context)
    }

    private func update(_ rule: ReminderRule, in context: ReminderContext) {
        if context == .work {
            replace(rule, in: &workReminders)
            persist(workReminders, key: Key.workReminders)
        } else {
            replace(rule, in: &idleReminders)
            persist(idleReminders, key: Key.idleReminders)
        }
    }

    private func replace(_ rule: ReminderRule, in rules: inout [ReminderRule]) {
        if let index = rules.firstIndex(where: { $0.behavior == rule.behavior }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func loadRules(from defaults: UserDefaults, key: String, fallback: [ReminderRule]) -> [ReminderRule] {
        guard let rules = decode([ReminderRule].self, from: defaults, key: key) else { return fallback }
        var result = fallback
        for rule in rules {
            if let index = result.firstIndex(where: { $0.behavior == rule.behavior }) {
                result[index] = rule
            }
        }
        return result.map { rule in
            var customRule = rule
            customRule.frequency = rule.frequency.customValue
            return customRule
        }
    }

    private static func loadLeadTime(from defaults: UserDefaults) -> TimeInterval {
        let value = (defaults.object(forKey: Key.sleepReminderLeadTime) as? NSNumber)?.doubleValue ?? ReminderTiming.defaultSleepReminderLeadTime
        return min(max(value, ReminderTiming.minimumSleepReminderLeadTime), ReminderTiming.maximumSleepReminderLeadTime)
    }
}

@MainActor
final class MacReminderHistoryStore: ObservableObject {
    private let defaults: UserDefaults
    private let key = "reminderEvents"
    @Published private(set) var events: [ReminderEvent]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode([ReminderEvent].self, from: data) {
            events = saved
        } else {
            events = []
        }
    }

    static func preview() -> MacReminderHistoryStore {
        MacReminderHistoryStore(defaults: UserDefaults(suiteName: "igotu.mac.preview.history") ?? .standard)
    }

    func completedEvents(on date: Date = .now) -> [ReminderEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.filter {
            !$0.isTest && $0.status == .acknowledged && ($0.resolvedAt ?? $0.timestamp) >= start && ($0.resolvedAt ?? $0.timestamp) < end
        }
    }

    func event(for eventID: UUID) -> ReminderEvent? {
        events.first { $0.id == eventID }
    }

    @discardableResult
    func recordScheduled(behavior: Behavior, context: ReminderContext, dueAt: Date, now: Date = .now) -> ReminderEvent {
        let event = ReminderEvent(behavior: behavior, context: context, timestamp: dueAt, status: .scheduled)
        var updated = currentEvents(now: now)
        updated.append(event)
        persist(updated, now: now)
        return event
    }

    @discardableResult
    func updateStatus(for eventID: UUID, to status: ReminderEventStatus, at date: Date = .now) -> Bool {
        var updated = currentEvents(now: date)
        guard let index = updated.firstIndex(where: { $0.id == eventID }), !updated[index].status.isTerminal,
              updated[index].status != status, canTransition(from: updated[index].status, to: status) else { return false }
        updated[index].status = status
        updated[index].resolvedAt = status.isTerminal ? date : nil
        persist(updated, now: date)
        return true
    }

    @discardableResult
    func expireScheduledEvents(before date: Date = .now, gracePeriod: TimeInterval = 0) -> [ReminderEvent] {
        var updated = currentEvents(now: date)
        var expired: [ReminderEvent] = []
        for index in updated.indices where updated[index].status == .scheduled || updated[index].status == .delivered {
            guard updated[index].timestamp.addingTimeInterval(gracePeriod) <= date else { continue }
            updated[index].status = .expired
            updated[index].resolvedAt = date
            expired.append(updated[index])
        }
        if !expired.isEmpty { persist(updated, now: date) }
        return expired
    }

    private func currentEvents(now: Date) -> [ReminderEvent] {
        let cutoff = now.addingTimeInterval(-ReminderTiming.historyRetention)
        return events.filter { $0.timestamp >= cutoff }
    }

    private func canTransition(from current: ReminderEventStatus, to next: ReminderEventStatus) -> Bool {
        switch current {
        case .scheduled: return next == .delivered || next == .acknowledged || next == .skipped || next == .expired || next == .cancelled
        case .delivered: return next == .acknowledged || next == .skipped || next == .expired
        case .acknowledged, .skipped, .expired, .cancelled: return false
        }
    }

    private func persist(_ values: [ReminderEvent], now: Date) {
        let cutoff = now.addingTimeInterval(-ReminderTiming.historyRetention)
        events = values.filter { $0.timestamp >= cutoff }
        if let data = try? JSONEncoder().encode(events) { defaults.set(data, forKey: key) }
    }
}
