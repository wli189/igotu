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
    private let planningHorizon: TimeInterval
    private let maximumReminderCount: Int

    init(
        engine: ReminderEngine,
        timeline: DailyScheduleTimeline = DailyScheduleTimeline(),
        intervalLimit: Int = 32,
        planningHorizon: TimeInterval = ReminderTiming.notificationPlanningHorizon,
        maximumReminderCount: Int = ReminderTiming.maximumPendingBehaviorNotifications
    ) {
        self.engine = engine
        self.timeline = timeline
        self.intervalLimit = intervalLimit
        self.planningHorizon = max(0, planningHorizon)
        self.maximumReminderCount = max(0, maximumReminderCount)
    }

    func plan(
        for schedule: DailySchedule,
        workRules: [ReminderRule],
        idleRules: [ReminderRule],
        events: [ReminderEvent],
        now: Date = .now,
        rollingFrom: Date? = nil,
        compensationCandidates: [ReminderCandidate] = []
    ) -> ReminderPlan {
        let planningStart = rollingFrom ?? now
        let horizonEnd = planningStart.addingTimeInterval(planningHorizon)
        let pendingEvents = events
            .filter { $0.status == .scheduled && $0.timestamp >= now }
            .sorted { first, second in
                if first.timestamp != second.timestamp {
                    return first.timestamp < second.timestamp
                }

                return first.id.uuidString < second.id.uuidString
            }

        var retainedReminders: [PlannedReminder] = []
        var eventIDsToCancel = Set<UUID>()

        if rollingFrom != nil {
            eventIDsToCancel = Set(
                events
                    .filter { $0.status == .scheduled && $0.timestamp >= now }
                    .map(\.id)
            )
        } else {
            for event in pendingEvents {
                guard event.timestamp < horizonEnd else {
                    eventIDsToCancel.insert(event.id)
                    continue
                }

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

                retainedReminders.append(PlannedReminder(
                    eventID: event.id,
                    candidate: candidate
                ))
            }
        }

        var planned = retainedReminders
        var planningEvents = events.filter { event in
            guard event.status.countsTowardCooldown else { return false }
            guard let anchor = event.cooldownAnchor(
                expirationGracePeriod: ReminderTiming.expirationGracePeriod
            ) else {
                return false
            }

            guard anchor <= planningStart else { return false }

            if rollingFrom != nil,
               event.status == .scheduled,
               event.timestamp >= now
            {
                return false
            }

            return true
        }

        for retainedReminder in retainedReminders {
            guard let eventID = retainedReminder.eventID else { continue }

            planningEvents.append(ReminderEvent(
                id: eventID,
                behavior: retainedReminder.candidate.behavior,
                context: context(for: retainedReminder.candidate.mode),
                timestamp: retainedReminder.candidate.dueAt,
                status: .scheduled
            ))
        }

        let validCompensations = compensationCandidates.filter { candidate in
            candidate.dueAt >= planningStart
                && candidate.dueAt < horizonEnd
                && rule(
                    for: candidate.behavior,
                    in: candidate.mode,
                    workRules: workRules,
                    idleRules: idleRules
                )?.isEnabled == true
                && timeline.currentInterval(for: schedule, at: candidate.dueAt).mode
                    == candidate.mode
        }

        for compensation in validCompensations {
            let alreadyPlanned = planned.contains {
                $0.candidate.behavior == compensation.behavior
                    && $0.candidate.dueAt == compensation.dueAt
            }

            guard !alreadyPlanned else { continue }

            planned.append(PlannedReminder(
                eventID: nil,
                candidate: compensation
            ))
            planningEvents.append(ReminderEvent(
                behavior: compensation.behavior,
                context: context(for: compensation.mode),
                timestamp: compensation.dueAt,
                status: .scheduled
            ))
        }

        for interval in timeline.intervals(
            for: schedule,
            startingAt: planningStart,
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

            let intervalEnd = min(interval.end, horizonEnd)
            guard interval.start < horizonEnd, interval.start < intervalEnd else {
                continue
            }

            for rule in rules where rule.isEnabled {
                var planningNow = max(planningStart, interval.start)

                while planningNow < intervalEnd {
                    let existingDueAt = planned.filter { reminder in
                        reminder.candidate.behavior == rule.behavior
                            && reminder.candidate.mode == interval.mode
                            && reminder.candidate.dueAt >= planningNow
                            && reminder.candidate.dueAt < intervalEnd
                    }
                    .map(\.candidate.dueAt)
                    .min()

                    if let existingDueAt {
                        planningNow = existingDueAt
                    }

                    guard let candidate = engine.nextReminder(from: ReminderEngineInput(
                        now: planningNow,
                        mode: interval.mode,
                        rules: [rule],
                        recentEvents: planningEvents,
                        activeInterval: interval
                    )) else {
                        break
                    }

                    guard candidate.dueAt < intervalEnd,
                          candidate.dueAt < horizonEnd else {
                        break
                    }

                    let alreadyPlanned = planned.contains {
                        $0.candidate.behavior == candidate.behavior
                            && $0.candidate.mode == candidate.mode
                            && $0.candidate.dueAt == candidate.dueAt
                    }

                    if !alreadyPlanned {
                        planned.append(PlannedReminder(
                            eventID: nil,
                            candidate: candidate
                        ))
                        planningEvents.append(ReminderEvent(
                            behavior: candidate.behavior,
                            context: context(for: candidate.mode),
                            timestamp: candidate.dueAt,
                            status: .scheduled
                        ))
                    }

                    guard candidate.dueAt > planningNow else { break }
                    planningNow = candidate.dueAt
                }
            }
        }

        let sortedReminders = planned.sorted(by: sortReminders)
        let limitedReminders = Array(sortedReminders.prefix(maximumReminderCount))

        for reminder in sortedReminders.dropFirst(maximumReminderCount) {
            if let eventID = reminder.eventID {
                eventIDsToCancel.insert(eventID)
            }
        }

        return ReminderPlan(
            reminders: limitedReminders,
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

    private func context(for mode: DailyMode) -> ReminderContext {
        switch mode {
        case .work: return .work
        case .idle, .sleeping: return .idle
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
