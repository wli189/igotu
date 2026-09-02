import Foundation

struct PlannedReminder: Equatable {
    let eventID: UUID?
    let candidate: ReminderCandidate
}

struct ReminderPlan: Equatable {
    let reminders: [PlannedReminder]
    let eventIDsToCancel: Set<UUID>
}

/// Builds the desired reminder set without touching persistence or platform APIs.
struct ReminderPlanner {
    private let engine: ReminderEngine
    private let timeline: DailyScheduleTimeline
    private let intervalLimit: Int

    init(
        engine: ReminderEngine,
        timeline: DailyScheduleTimeline = DailyScheduleTimeline(),
        intervalLimit: Int = 32
    ) {
        self.engine = engine
        self.timeline = timeline
        self.intervalLimit = intervalLimit
    }

    func plan(
        for schedule: DailySchedule,
        workRules: [ReminderRule],
        idleRules: [ReminderRule],
        events: [ReminderEvent],
        now: Date = .now
    ) -> ReminderPlan {
        let pendingEvents = events
            .filter { $0.status == .scheduled && $0.timestamp >= now }
            .sorted { first, second in
                if first.timestamp != second.timestamp {
                    return first.timestamp < second.timestamp
                }

                return first.id.uuidString < second.id.uuidString
            }

        var retainedByBehavior: [Behavior: PlannedReminder] = [:]
        var eventIDsToCancel = Set<UUID>()

        for event in pendingEvents {
            guard let candidate = validCandidate(
                for: event,
                schedule: schedule,
                workRules: workRules,
                idleRules: idleRules,
                now: now
            ) else {
                eventIDsToCancel.insert(event.id)
                continue
            }

            if retainedByBehavior[event.behavior] == nil {
                retainedByBehavior[event.behavior] = PlannedReminder(
                    eventID: event.id,
                    candidate: candidate
                )
            } else {
                eventIDsToCancel.insert(event.id)
            }
        }

        let recentEvents = events.filter { event in
            guard event.status.countsTowardCooldown else { return false }

            guard let anchor = event.cooldownAnchor(
                expirationGracePeriod: ReminderTiming.expirationGracePeriod
            ) else {
                return false
            }

            return anchor <= now
        }

        var planned = retainedByBehavior
        for interval in timeline.intervals(
            for: schedule,
            startingAt: now,
            count: intervalLimit
        ) {
            let rules: [ReminderRule]

            switch interval.mode {
            case .sleeping:
                continue
            case .work:
                rules = workRules
            case .idle:
                rules = idleRules
            }

            let planningNow = max(now, interval.start)
            let candidates = engine.nextReminders(from: ReminderEngineInput(
                now: planningNow,
                mode: interval.mode,
                rules: rules,
                recentEvents: recentEvents,
                activeInterval: interval
            ))

            for candidate in candidates where planned[candidate.behavior] == nil {
                planned[candidate.behavior] = PlannedReminder(
                    eventID: nil,
                    candidate: candidate
                )
            }
        }

        return ReminderPlan(
            reminders: planned.values.sorted(by: sortReminders),
            eventIDsToCancel: eventIDsToCancel
        )
    }

    private func validCandidate(
        for event: ReminderEvent,
        schedule: DailySchedule,
        workRules: [ReminderRule],
        idleRules: [ReminderRule],
        now: Date
    ) -> ReminderCandidate? {
        guard event.timestamp >= now,
              let mode = mode(for: event.context),
              let rule = rule(
                  for: event.behavior,
                  in: mode,
                  workRules: workRules,
                  idleRules: idleRules
              ),
              rule.isEnabled,
              timeline.currentInterval(for: schedule, at: event.timestamp).mode == mode
        else {
            return nil
        }

        return ReminderCandidate(
            behavior: event.behavior,
            mode: mode,
            dueAt: event.timestamp
        )
    }

    private func rule(
        for behavior: Behavior,
        in mode: DailyMode,
        workRules: [ReminderRule],
        idleRules: [ReminderRule]
    ) -> ReminderRule? {
        let rules: [ReminderRule]

        switch mode {
        case .sleeping:
            return nil
        case .work:
            rules = workRules
        case .idle:
            rules = idleRules
        }

        return rules.first { $0.behavior == behavior }
    }

    private func mode(for context: ReminderContext) -> DailyMode? {
        switch context {
        case .work:
            return .work
        case .idle:
            return .idle
        }
    }

    private func sortReminders(
        _ first: PlannedReminder,
        _ second: PlannedReminder
    ) -> Bool {
        if first.candidate.dueAt != second.candidate.dueAt {
            return first.candidate.dueAt < second.candidate.dueAt
        }

        return first.candidate.behavior.reminderPriority
            < second.candidate.behavior.reminderPriority
    }
}
