import Foundation

struct ReminderPlanner {
    private let engine: ReminderEngine
    private let timeline: DailyScheduleTimeline
    private let intervalLimit = 32

    init(
        engine: ReminderEngine,
        timeline: DailyScheduleTimeline = DailyScheduleTimeline()
    ) {
        self.engine = engine
        self.timeline = timeline
    }

    func nextReminders(
        for schedule: DailySchedule,
        workRules: [ReminderRule],
        idleRules: [ReminderRule],
        recentEvents: [ReminderEvent],
        pendingReminders: [ScheduledReminder] = [],
        now: Date = .now
    ) -> [ReminderCandidate] {
        var candidates: [ReminderCandidate] = []
        let validPendingCandidates = pendingReminders
            .compactMap { pending in
                validPendingCandidate(
                    pending.candidate,
                    for: schedule,
                    workRules: workRules,
                    idleRules: idleRules,
                    now: now
                )
            }
            .sorted(by: sortCandidates)

        var pendingCandidateByBehavior: [Behavior: ReminderCandidate] = [:]
        for candidate in validPendingCandidates {
            pendingCandidateByBehavior[candidate.behavior] =
                pendingCandidateByBehavior[candidate.behavior] ?? candidate
        }

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
            let intervalCandidates = engine.nextReminders(from: ReminderEngineInput(
                now: planningNow,
                mode: interval.mode,
                rules: rules,
                recentEvents: recentEvents,
                activeInterval: interval
            ))

            for candidate in intervalCandidates
                where !candidates.contains(where: { $0.behavior == candidate.behavior })
            {
                candidates.append(
                    pendingCandidateByBehavior[candidate.behavior] ?? candidate
                )
            }
        }

        for candidate in validPendingCandidates
            where !candidates.contains(where: { $0.behavior == candidate.behavior })
        {
            candidates.append(candidate)
        }

        return candidates.sorted(by: sortCandidates)
    }

    private func validPendingCandidate(
        _ candidate: ReminderCandidate,
        for schedule: DailySchedule,
        workRules: [ReminderRule],
        idleRules: [ReminderRule],
        now: Date
    ) -> ReminderCandidate? {
        guard candidate.mode != .sleeping,
              candidate.dueAt >= now,
              let rule = rule(
                  for: candidate.behavior,
                  in: candidate.mode,
                  workRules: workRules,
                  idleRules: idleRules
              ),
              rule.isEnabled,
              timeline.currentInterval(for: schedule, at: candidate.dueAt).mode
                  == candidate.mode else {
            return nil
        }

        return candidate
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

    private func sortCandidates(
        _ first: ReminderCandidate,
        _ second: ReminderCandidate
    ) -> Bool {
        if first.dueAt != second.dueAt {
            return first.dueAt < second.dueAt
        }

        return first.behavior.reminderPriority < second.behavior.reminderPriority
    }
}
