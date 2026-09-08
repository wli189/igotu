import Foundation

public struct ReminderEngineInput {
    public let now: Date
    public let mode: DailyMode
    public let rules: [ReminderRule]
    public let recentEvents: [ReminderEvent]
    public let activeInterval: DailyScheduleInterval?

    public init(
        now: Date,
        mode: DailyMode,
        rules: [ReminderRule],
        recentEvents: [ReminderEvent],
        activeInterval: DailyScheduleInterval? = nil
    ) {
        self.now = now
        self.mode = mode
        self.rules = rules
        self.recentEvents = recentEvents
        self.activeInterval = activeInterval
    }
}

public struct ReminderCandidate: Equatable {
    public let behavior: Behavior
    public let mode: DailyMode
    public let dueAt: Date

    public init(behavior: Behavior, mode: DailyMode, dueAt: Date) {
        self.behavior = behavior
        self.mode = mode
        self.dueAt = dueAt
    }
}

public struct ReminderEngine {
    public typealias OffsetProvider = (ReminderFrequency) -> TimeInterval

    private let offsetProvider: OffsetProvider
    private let expirationGracePeriod: TimeInterval

    public init(
        offsetProvider: @escaping OffsetProvider = { frequency in
            let lowerBoundMinutes = Int((frequency.offsetRange.lowerBound / 60).rounded(.up))
            let upperBoundMinutes = Int((frequency.offsetRange.upperBound / 60).rounded(.down))
            return TimeInterval(Int.random(in: lowerBoundMinutes ... upperBoundMinutes) * 60)
        },
        expirationGracePeriod: TimeInterval = ReminderTiming.expirationGracePeriod
    ) {
        self.offsetProvider = offsetProvider
        self.expirationGracePeriod = expirationGracePeriod
    }

    public func nextReminder(from input: ReminderEngineInput) -> ReminderCandidate? {
        nextReminders(from: input).first
    }

    public func nextReminders(from input: ReminderEngineInput) -> [ReminderCandidate] {
        guard context(for: input.mode) != nil else {
            return []
        }

        let lastAnchorByBehavior = Dictionary(
            grouping: input.recentEvents.filter { $0.status.countsTowardCooldown },
            by: \.behavior
        ).compactMapValues { events in
            events.compactMap {
                $0.cooldownAnchor(expirationGracePeriod: expirationGracePeriod)
            }.filter { $0 <= input.now }.max()
        }

        return input.rules
            .filter(\.isEnabled)
            .compactMap { rule in
                let dueAt = nextDueDate(
                    for: rule,
                    lastAnchor: lastAnchorByBehavior[rule.behavior],
                    now: input.now
                )

                let candidate = ReminderCandidate(
                    behavior: rule.behavior,
                    mode: input.mode,
                    dueAt: dueAt
                )

                guard isWithinActiveInterval(candidate, input: input) else {
                    return nil
                }

                return candidate
            }
            .sorted { first, second in
                if first.dueAt != second.dueAt {
                    return first.dueAt < second.dueAt
                }

                return first.behavior.reminderPriority < second.behavior.reminderPriority
            }
    }

    private func nextDueDate(
        for rule: ReminderRule,
        lastAnchor: Date?,
        now: Date
    ) -> Date {
        guard let lastAnchor else {
            return dueDate(
                after: now,
                frequency: rule.frequency,
                now: now
            )
        }

        return dueDate(
            after: lastAnchor,
            frequency: rule.frequency,
            now: now
        )
    }

    private func dueDate(
        after date: Date,
        frequency: ReminderFrequency,
        now: Date
    ) -> Date {
        // Keep the schedule formula stable: reference point + interval + offset.
        let targetDate = date.addingTimeInterval(
            frequency.interval + offsetProvider(frequency)
        )

        return max(now, targetDate)
    }

    private func context(for mode: DailyMode) -> ReminderContext? {
        switch mode {
        case .sleeping: return nil
        case .work: return .work
        case .idle: return .idle
        }
    }

    private func isWithinActiveInterval(
        _ candidate: ReminderCandidate,
        input: ReminderEngineInput
    ) -> Bool {
        guard let interval = input.activeInterval else { return true }

        return interval.mode == candidate.mode
            && interval.start <= candidate.dueAt
            && candidate.dueAt < interval.end
    }
}
