import Foundation

struct ReminderEngineInput {
    let now: Date
    let mode: DailyMode
    let rules: [ReminderRule]
    let recentEvents: [ReminderEvent]
}

struct ReminderCandidate: Equatable {
    let behavior: Behavior
    let mode: DailyMode
    let dueAt: Date
}

struct ReminderEngine {
    typealias OffsetProvider = (ReminderFrequency) -> TimeInterval

    private let offsetProvider: OffsetProvider
    private let expirationGracePeriod: TimeInterval

    init(
        offsetProvider: @escaping OffsetProvider = { frequency in
            Double.random(in: frequency.offsetRange)
        },
        expirationGracePeriod: TimeInterval = ReminderTiming.liveActivityGracePeriod
    ) {
        self.offsetProvider = offsetProvider
        self.expirationGracePeriod = expirationGracePeriod
    }

    func nextReminder(from input: ReminderEngineInput) -> ReminderCandidate? {
        nextReminders(from: input).first
    }

    func nextReminders(from input: ReminderEngineInput) -> [ReminderCandidate] {
        guard let context = context(for: input.mode) else {
            return []
        }

        let lastAnchorByBehavior = Dictionary(
            grouping: input.recentEvents.filter {
                $0.context == context && $0.status.countsTowardCooldown
            },
            by: \.behavior
        ).compactMapValues { events in
            events.compactMap {
                $0.cooldownAnchor(expirationGracePeriod: expirationGracePeriod)
            }.max()
        }

        return input.rules
            .filter(\.isEnabled)
            .compactMap { rule in
                let dueAt = nextDueDate(
                    for: rule,
                    lastAnchor: lastAnchorByBehavior[rule.behavior],
                    now: input.now
                )

                return ReminderCandidate(
                    behavior: rule.behavior,
                    mode: input.mode,
                    dueAt: dueAt
                )
            }
            .sorted { first, second in
                if first.dueAt != second.dueAt {
                    return first.dueAt < second.dueAt
                }

                return priority(of: first.behavior) < priority(of: second.behavior)
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

    private func priority(of behavior: Behavior) -> Int {
        switch behavior {
        case .standUp: return 0
        case .hydration: return 1
        case .movement: return 2
        }
    }
}
