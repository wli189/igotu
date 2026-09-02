import Foundation
import Combine

@MainActor
final class ReminderCoordinator: ObservableObject {
    private let configuration: AppConfigurationStore
    private let planner: ReminderPlanner
    private let history: ReminderHistoryStore
    private let notificationScheduler: NotificationScheduler

    private var refreshInProgress = false
    private var queuedRefreshRequest: RefreshRequest?

    private struct RefreshRequest {
        let rollingFrom: Date?
        let compensationCandidates: [ReminderCandidate]

        static let normal = RefreshRequest(
            rollingFrom: nil,
            compensationCandidates: []
        )

        func merged(with other: RefreshRequest) -> RefreshRequest {
            let rollingFrom: Date?
            switch (self.rollingFrom, other.rollingFrom) {
            case let (first?, second?):
                rollingFrom = max(first, second)
            case let (first?, nil):
                rollingFrom = first
            case let (nil, second?):
                rollingFrom = second
            case (nil, nil):
                rollingFrom = nil
            }

            return RefreshRequest(
                rollingFrom: rollingFrom,
                compensationCandidates: compensationCandidates
                    + other.compensationCandidates
            )
        }
    }

    init(
        configuration: AppConfigurationStore,
        engine: ReminderEngine,
        history: ReminderHistoryStore,
        notificationScheduler: NotificationScheduler
    ) {
        self.configuration = configuration
        self.planner = ReminderPlanner(engine: engine)
        self.history = history
        self.notificationScheduler = notificationScheduler

        notificationScheduler.configure { [weak self] action in
            self?.handle(action)
        }
    }

    func refresh() async {
        await refresh(with: .normal)
    }

    func refreshRollingFromNow() async {
        await refresh(rollingFrom: .now)
    }

    private func refresh(with request: RefreshRequest) async {
        if refreshInProgress {
            queuedRefreshRequest = (queuedRefreshRequest ?? .normal)
                .merged(with: request)
            return
        }

        refreshInProgress = true
        defer { refreshInProgress = false }

        var currentRequest = request
        while true {
            await performRefresh(with: currentRequest)

            guard let queuedRefreshRequest else { break }
            self.queuedRefreshRequest = nil
            currentRequest = queuedRefreshRequest
        }
    }

    private func refresh(
        rollingFrom date: Date,
        compensationCandidates: [ReminderCandidate] = []
    ) async {
        await refresh(with: RefreshRequest(
            rollingFrom: date,
            compensationCandidates: compensationCandidates
        ))
    }

    @discardableResult
    func scheduleTestNotification(for behavior: Behavior) async -> Bool {
        guard await notificationScheduler.requestPermissionIfNeeded() else {
            return false
        }

        do {
            try await notificationScheduler.scheduleTestNotification(for: behavior)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func scheduleTestSleepReminder() async -> Bool {
        guard await notificationScheduler.requestPermissionIfNeeded() else {
            return false
        }

        do {
            try await notificationScheduler.scheduleTestSleepReminder()
            return true
        } catch {
            return false
        }
    }

    func clearTestNotifications() async {
        await notificationScheduler.removeTestNotifications()
    }

    func pendingTestNotifications() async -> [ScheduledTestNotification] {
        await notificationScheduler.pendingTestNotifications()
    }

    private func performRefresh(with request: RefreshRequest) async {
        guard configuration.hasCompletedSetup else { return }

        await notificationScheduler.removeLegacyBehaviorReminders()
        _ = await notificationScheduler.requestPermissionIfNeeded()

        let now = Date.now
        let expiredEvents = history.expireScheduledEvents(
            before: now,
            gracePeriod: ReminderTiming.expirationGracePeriod
        )

        var rollingFrom = request.rollingFrom
        var compensationCandidates = request.compensationCandidates

        if !expiredEvents.isEmpty {
            let compensationDate = now.addingTimeInterval(
                ReminderTiming.compensationDelay
            )
            rollingFrom = max(rollingFrom ?? compensationDate, compensationDate)

            compensationCandidates += expiredEvents.compactMap { event in
                compensationCandidate(
                    for: event,
                    dueAt: compensationDate
                )
            }
        }

        if let earliestCompensation = compensationCandidates.map(\.dueAt).min() {
            rollingFrom = max(rollingFrom ?? earliestCompensation, earliestCompensation)
        }

        let plan = planner.plan(
            for: configuration.schedule,
            workRules: configuration.workReminders,
            idleRules: configuration.idleReminders,
            events: history.events,
            now: now,
            rollingFrom: rollingFrom,
            compensationCandidates: compensationCandidates
        )

        for eventID in plan.eventIDsToCancel {
            history.updateStatus(for: eventID, to: .cancelled, at: now)
        }
        await notificationScheduler.removeBehaviorReminders(
            for: plan.eventIDsToCancel
        )

        var pendingEventIDs = await notificationScheduler.pendingBehaviorEventIDs()
        var desiredEventIDs = Set<UUID>()

        for plannedReminder in plan.reminders {
            let event: ReminderEvent

            if let eventID = plannedReminder.eventID,
               let existingEvent = history.event(for: eventID)
            {
                event = existingEvent
            } else {
                event = history.recordScheduled(
                    behavior: plannedReminder.candidate.behavior,
                    context: context(for: plannedReminder.candidate.mode),
                    dueAt: plannedReminder.candidate.dueAt,
                    now: now
                )
            }

            desiredEventIDs.insert(event.id)

            guard !pendingEventIDs.contains(event.id) else { continue }

            do {
                try await notificationScheduler.schedule(event: event)
                pendingEventIDs.insert(event.id)
            } catch {
                history.updateStatus(for: event.id, to: .cancelled, at: now)
            }
        }

        await notificationScheduler.removeStaleBehaviorReminders(
            keeping: desiredEventIDs
        )

        do {
            try await notificationScheduler.scheduleSleepReminderIfNeeded(
                for: configuration.schedule,
                leadTime: configuration.sleepReminderLeadTime,
                now: now
            )
        } catch {
            // A notification scheduling failure must not prevent the app from opening.
        }
    }

    private func handle(_ action: ReminderAction) {
        switch action {
        case let .delivered(eventID, date):
            history.updateStatus(for: eventID, to: .delivered, at: date)
            Task { [weak self] in
                await self?.refresh()
            }
        case let .acknowledged(eventID, date):
            history.updateStatus(for: eventID, to: .acknowledged, at: date)
            Task { [weak self] in
                await self?.refresh(rollingFrom: date)
            }
        case let .skipped(eventID, date):
            history.updateStatus(for: eventID, to: .skipped, at: date)
            let compensationDate = date.addingTimeInterval(
                ReminderTiming.compensationDelay
            )
            let compensation = history.event(for: eventID).flatMap { event in
                compensationCandidate(for: event, dueAt: compensationDate)
            }

            Task { [weak self] in
                await self?.refresh(
                    rollingFrom: compensationDate,
                    compensationCandidates: compensation.map { [$0] } ?? []
                )
            }
        }
    }

    private func compensationCandidate(
        for event: ReminderEvent,
        dueAt: Date
    ) -> ReminderCandidate? {
        let mode: DailyMode
        switch event.context {
        case .work:
            mode = .work
        case .idle:
            mode = .idle
        }

        return ReminderCandidate(
            behavior: event.behavior,
            mode: mode,
            dueAt: dueAt
        )
    }

    private func context(for mode: DailyMode) -> ReminderContext {
        switch mode {
        case .work: return .work
        case .idle, .sleeping: return .idle
        }
    }
}
