import Foundation
import Combine

@MainActor
final class ReminderCoordinator: ObservableObject {
    @Published private(set) var toastReminders: [ReminderEvent] = []
    @Published private(set) var fullScreenReminder: ReminderEvent?

    private let configuration: AppConfigurationStore
    private let planner: ReminderPlanner
    private let history: ReminderHistoryStore
    private let notificationScheduler: NotificationScheduler

    private var refreshInProgress = false
    private var queuedRefreshRequest: RefreshRequest?

    private struct RefreshRequest {
        let rollingFrom: Date?
        let rollingBehaviors: Set<Behavior>?
        let compensationCandidates: [ReminderCandidate]

        static let normal = RefreshRequest(
            rollingFrom: nil,
            rollingBehaviors: nil,
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

            let rollingBehaviors: Set<Behavior>?
            if self.rollingFrom == nil {
                rollingBehaviors = other.rollingFrom == nil
                    ? nil
                    : other.rollingBehaviors
            } else if other.rollingFrom == nil {
                rollingBehaviors = self.rollingBehaviors
            } else if let first = self.rollingBehaviors,
                      let second = other.rollingBehaviors
            {
                rollingBehaviors = first.union(second)
            } else {
                rollingBehaviors = nil
            }

            return RefreshRequest(
                rollingFrom: rollingFrom,
                rollingBehaviors: rollingBehaviors,
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

    func refreshRollingFromNow(for behavior: Behavior? = nil) async {
        await refresh(
            rollingFrom: .now,
            rollingBehaviors: behavior.map { Set([$0]) }
        )
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
        rollingBehaviors: Set<Behavior>? = nil,
        compensationCandidates: [ReminderCandidate] = []
    ) async {
        await refresh(with: RefreshRequest(
            rollingFrom: date,
            rollingBehaviors: rollingBehaviors,
            compensationCandidates: compensationCandidates
        ))
    }

    @discardableResult
    func scheduleTestNotification(for behavior: Behavior) async -> Bool {
        guard await notificationScheduler.requestPermissionIfNeeded() else {
            return false
        }

        let fireDate = Date.now.addingTimeInterval(60)
        let mode = DailyModeManager().currentMode(
            for: configuration.schedule,
            at: fireDate
        )
        let event = history.recordScheduled(
            behavior: behavior,
            context: context(for: mode),
            dueAt: fireDate,
            isTest: true
        )

        do {
            try await notificationScheduler.scheduleTestNotification(for: event)
            return true
        } catch {
            history.cancelTestEvents(withIDs: [event.id])
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
        let scheduledTestEventIDs = Set(
            history.events.filter(\.isTest).map(\.id)
        )
        let notificationEventIDs = await notificationScheduler.removeTestNotifications()
        let eventIDs = scheduledTestEventIDs.union(notificationEventIDs)
        history.cancelTestEvents(withIDs: eventIDs)

        toastReminders.removeAll { eventIDs.contains($0.id) }
        if let fullScreenReminder,
           eventIDs.contains(fullScreenReminder.id)
        {
            self.fullScreenReminder = nil
        }
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
        let realExpiredEvents = expiredEvents.filter { !$0.isTest }

        var rollingFrom = request.rollingFrom
        var rollingBehaviors = request.rollingBehaviors
        var compensationCandidates = request.compensationCandidates

        if !expiredEvents.isEmpty {
            let expiredEventIDs = Set(expiredEvents.map(\.id))
            toastReminders.removeAll { expiredEventIDs.contains($0.id) }
            if let fullScreenReminder,
               expiredEventIDs.contains(fullScreenReminder.id)
            {
                self.fullScreenReminder = nil
            }
        }

        if !realExpiredEvents.isEmpty {
            let compensationDate = now.addingTimeInterval(
                ReminderTiming.compensationDelay
            )
            rollingFrom = max(rollingFrom ?? compensationDate, compensationDate)

            let expiredBehaviors = Set(realExpiredEvents.map(\.behavior))
            if request.rollingFrom == nil {
                rollingBehaviors = expiredBehaviors
            } else if let currentRollingBehaviors = rollingBehaviors {
                var mergedBehaviors = currentRollingBehaviors
                mergedBehaviors.formUnion(expiredBehaviors)
                rollingBehaviors = mergedBehaviors
            }

            compensationCandidates += realExpiredEvents.compactMap { event in
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
            rollingBehaviors: rollingBehaviors,
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
            guard history.updateStatus(for: eventID, to: .delivered, at: date) else {
                return
            }
            enqueueToast(for: eventID)
            Task { [weak self] in
                await self?.refresh()
            }
        case let .opened(eventID, date):
            guard let event = history.event(for: eventID),
                  !event.status.isTerminal
            else {
                return
            }

            if event.status == .scheduled {
                _ = history.updateStatus(for: eventID, to: .delivered, at: date)
            }

            toastReminders.removeAll { $0.id == eventID }
            fullScreenReminder = history.event(for: eventID)
        case let .acknowledged(eventID, date):
            guard let event = history.event(for: eventID),
                  history.updateStatus(
                      for: eventID,
                      to: .acknowledged,
                      at: date
                  )
            else {
                return
            }
            removePrompt(for: eventID)
            guard !event.isTest else { return }
            Task { [weak self] in
                await self?.refresh(
                    rollingFrom: date,
                    rollingBehaviors: [event.behavior]
                )
            }
        case let .skipped(eventID, date):
            guard let event = history.event(for: eventID),
                  history.updateStatus(
                      for: eventID,
                      to: .skipped,
                      at: date
                  )
            else {
                return
            }
            removePrompt(for: eventID)
            guard !event.isTest else { return }
            let compensationDate = date.addingTimeInterval(
                ReminderTiming.compensationDelay
            )
            guard let compensation = compensationCandidate(
                for: event,
                dueAt: compensationDate
            ) else {
                return
            }

            Task { [weak self] in
                await self?.refresh(
                    rollingFrom: compensationDate,
                    rollingBehaviors: [event.behavior],
                    compensationCandidates: [compensation]
                )
            }
        }
    }

    func acknowledge(eventID: UUID) {
        handle(.acknowledged(eventID: eventID, at: .now))
    }

    func skip(eventID: UUID) {
        handle(.skipped(eventID: eventID, at: .now))
    }

    func dismissFullScreenReminder() {
        fullScreenReminder = nil
    }

    private func enqueueToast(for eventID: UUID) {
        guard let event = history.event(for: eventID),
              !event.status.isTerminal,
              fullScreenReminder?.id != eventID,
              !toastReminders.contains(where: { $0.id == eventID })
        else {
            return
        }

        toastReminders.append(event)
    }

    private func removePrompt(for eventID: UUID) {
        toastReminders.removeAll { $0.id == eventID }
        if fullScreenReminder?.id == eventID {
            fullScreenReminder = nil
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
