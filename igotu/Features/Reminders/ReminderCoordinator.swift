import Foundation
import Combine
import IgotuCore

@MainActor
final class ReminderCoordinator: ObservableObject {
    @Published private(set) var toastReminders: [ReminderEvent] = []
    @Published private(set) var fullScreenReminder: ReminderEvent?
    @Published private(set) var isShowingExpiredReminderToast = false

    private let configuration: AppConfigurationStore
    private let planner: ReminderPlanner
    private let history: ReminderHistoryStore
    private let notificationScheduler: NotificationScheduler

    private var refreshInProgress = false
    private var queuedRefreshRequest: RefreshRequest?
    private var toastExpirationTasks: [UUID: Task<Void, Never>] = [:]
    private var expiredToastDismissalTask: Task<Void, Never>?

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
    func scheduleTestNotification(
        for behavior: Behavior,
        timing requestedTiming: ReminderTestTiming? = nil,
        after delay: TimeInterval? = nil
    ) async -> Bool {
        guard await notificationScheduler.requestPermissionIfNeeded() else {
            return false
        }

        let timing = requestedTiming ?? .defaultValue
        let fireDate = Date.now.addingTimeInterval(
            max(1, delay ?? timing.notificationDelay)
        )
        let mode = DailyModeManager().currentMode(
            for: configuration.schedule,
            at: fireDate
        )
        let event = history.recordScheduled(
            behavior: behavior,
            context: context(for: mode),
            dueAt: fireDate,
            isTest: true,
            testTiming: timing
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
    func scheduleTestSleepReminder(
        after delay: TimeInterval? = nil
    ) async -> Bool {
        guard await notificationScheduler.requestPermissionIfNeeded() else {
            return false
        }

        do {
            try await notificationScheduler.scheduleTestSleepReminder(after: delay)
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

        cancelToastExpirations(for: eventIDs)
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
        let expiredTestEvents = history.expireScheduledEvents(
            before: now,
            gracePeriod: ReminderTiming.testExpirationGracePeriod,
            isTest: true,
            gracePeriodForEvent: {
                $0.testTiming?.expirationGracePeriod
                    ?? ReminderTiming.testExpirationGracePeriod
            }
        )
        let expiredProductionEvents = history.expireScheduledEvents(
            before: now,
            gracePeriod: ReminderTiming.expirationGracePeriod,
            isTest: false
        )
        let expiredEvents = expiredTestEvents + expiredProductionEvents
        let realExpiredEvents = expiredEvents.filter { !$0.isTest }

        var rollingFrom = request.rollingFrom
        var rollingBehaviors = request.rollingBehaviors
        var compensationCandidates = request.compensationCandidates

        if !expiredEvents.isEmpty {
            let expiredEventIDs = Set(expiredEvents.map(\.id))
            cancelToastExpirations(for: expiredEventIDs)
            toastReminders.removeAll { expiredEventIDs.contains($0.id) }
            if let fullScreenReminder,
               expiredEventIDs.contains(fullScreenReminder.id)
            {
                self.fullScreenReminder = nil
            }
        }

        for event in expiredTestEvents {
            Task { [weak self] in
                _ = await self?.scheduleTestNotification(
                    for: event.behavior,
                    timing: event.testTiming ?? .defaultValue,
                    after: event.testTiming?.repeatDelay
                        ?? ReminderTiming.testRepeatDelay
                )
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
            studyRules: configuration.studyReminders,
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
            guard let event = history.event(for: eventID) else {
                return
            }

            let expirationDate = expirationDate(for: event)
            if event.status == .expired ||
                (!event.status.isTerminal && expirationDate <= date)
            {
                let didExpireOnOpen = history.updateStatus(
                    for: eventID,
                    to: .expired,
                    at: date
                )
                removePrompt(for: eventID)
                showExpiredReminderToast()

                if didExpireOnOpen {
                    if event.isTest {
                        Task { [weak self] in
                            _ = await self?.scheduleTestNotification(
                                for: event.behavior,
                                timing: event.testTiming ?? .defaultValue,
                                after: event.testTiming?.repeatDelay
                                    ?? ReminderTiming.testRepeatDelay
                            )
                        }
                    } else {
                        Task { [weak self] in
                            await self?.refresh()
                        }
                    }
                }
                return
            }

            guard !event.status.isTerminal else { return }

            if event.status == .scheduled {
                _ = history.updateStatus(for: eventID, to: .delivered, at: date)
            }

            cancelToastExpiration(for: eventID)
            toastReminders.removeAll { $0.id == eventID }
            fullScreenReminder = history.event(for: eventID)
            if let event = fullScreenReminder {
                scheduleToastExpiration(for: event)
            }
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
            if event.isTest {
                Task { [weak self] in
                    _ = await self?.scheduleTestNotification(
                        for: event.behavior,
                        timing: event.testTiming ?? .defaultValue,
                        after: event.testTiming?.repeatDelay
                            ?? ReminderTiming.testRepeatDelay
                    )
                }
                return
            }
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
        scheduleToastExpiration(for: event)
    }

    private func removePrompt(for eventID: UUID) {
        cancelToastExpiration(for: eventID)
        toastReminders.removeAll { $0.id == eventID }
        if fullScreenReminder?.id == eventID {
            fullScreenReminder = nil
        }
    }

    private func scheduleToastExpiration(for event: ReminderEvent) {
        cancelToastExpiration(for: event.id)

        let expirationDate = expirationDate(for: event)
        let delay = max(0, expirationDate.timeIntervalSinceNow)

        toastExpirationTasks[event.id] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard let self else { return }
            toastExpirationTasks[event.id] = nil
            await refresh()
        }
    }

    private func cancelToastExpiration(for eventID: UUID) {
        toastExpirationTasks.removeValue(forKey: eventID)?.cancel()
    }

    private func cancelToastExpirations(for eventIDs: Set<UUID>) {
        for eventID in eventIDs {
            cancelToastExpiration(for: eventID)
        }
    }

    private func expirationDate(for event: ReminderEvent) -> Date {
        let gracePeriod = event.isTest
            ? event.testTiming?.expirationGracePeriod
                ?? ReminderTiming.testExpirationGracePeriod
            : ReminderTiming.expirationGracePeriod
        return event.timestamp.addingTimeInterval(gracePeriod)
    }

    private func showExpiredReminderToast() {
        expiredToastDismissalTask?.cancel()
        isShowingExpiredReminderToast = true

        expiredToastDismissalTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(ReminderTiming.expiredToastPresentationDuration)
                )
            } catch {
                return
            }

            self?.isShowingExpiredReminderToast = false
            self?.expiredToastDismissalTask = nil
        }
    }

    private func compensationCandidate(
        for event: ReminderEvent,
        dueAt: Date
    ) -> ReminderCandidate? {
        guard let mode = DailyMode.allCases.first(where: {
            $0.reminderContext == event.context
        }) else {
            return nil
        }

        return ReminderCandidate(
            behavior: event.behavior,
            mode: mode,
            dueAt: dueAt
        )
    }

    private func context(for mode: DailyMode) -> ReminderContext {
        mode.reminderContext ?? .idle
    }
}
