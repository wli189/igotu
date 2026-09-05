import Foundation
import Combine
import IgotuCore

@MainActor
final class MacReminderCoordinator: ObservableObject {
    @Published private(set) var toastReminders: [ReminderEvent] = []
    @Published private(set) var fullScreenReminder: ReminderEvent?
    @Published private(set) var isShowingExpiredReminderToast = false

    private let configuration: MacConfigurationStore
    private let planner: ReminderPlanner
    private let history: MacReminderHistoryStore
    private let notificationScheduler: MacNotificationScheduler
    private var refreshInProgress = false
    private var refreshQueued = false
    private var toastExpirationTasks: [UUID: Task<Void, Never>] = [:]
    private var expiredToastTask: Task<Void, Never>?

    init(configuration: MacConfigurationStore, history: MacReminderHistoryStore, notificationScheduler: MacNotificationScheduler) {
        self.configuration = configuration
        self.planner = ReminderPlanner(engine: ReminderEngine())
        self.history = history
        self.notificationScheduler = notificationScheduler
        notificationScheduler.configure { [weak self] action in
            self?.handle(action)
        }
    }

    func refresh() async {
        await refresh(rollingFrom: nil, behaviors: nil)
    }

    func refreshRollingFromNow(for behavior: Behavior? = nil) async {
        await refresh(rollingFrom: .now, behaviors: behavior.map { Set([$0]) })
    }

    func acknowledge(eventID: UUID) {
        guard let event = history.event(for: eventID), history.updateStatus(for: eventID, to: .acknowledged) else { return }
        removePrompt(for: eventID)
        Task { await refreshRollingFromNow(for: event.behavior) }
    }

    func skip(eventID: UUID) {
        guard let event = history.event(for: eventID), history.updateStatus(for: eventID, to: .skipped) else { return }
        removePrompt(for: eventID)
        let dueAt = Date.now.addingTimeInterval(ReminderTiming.compensationDelay)
        guard let compensation = compensationCandidate(for: event, dueAt: dueAt) else { return }
        Task { await refresh(rollingFrom: dueAt, behaviors: [event.behavior], compensation: [compensation]) }
    }

    func dismissFullScreenReminder() {
        fullScreenReminder = nil
    }

    private func refresh(rollingFrom date: Date?, behaviors: Set<Behavior>?, compensation: [ReminderCandidate] = []) async {
        if refreshInProgress {
            refreshQueued = true
            return
        }
        refreshInProgress = true
        defer { refreshInProgress = false }

        var nextDate = date
        var nextBehaviors = behaviors
        var nextCompensation = compensation
        repeat {
            refreshQueued = false
            await performRefresh(rollingFrom: nextDate, behaviors: nextBehaviors, compensation: nextCompensation)
            nextDate = nil
            nextBehaviors = nil
            nextCompensation = []
        } while refreshQueued
    }

    private func performRefresh(rollingFrom date: Date?, behaviors: Set<Behavior>?, compensation: [ReminderCandidate]) async {
        guard configuration.hasCompletedSetup else { return }
        _ = await notificationScheduler.requestPermissionIfNeeded()
        await notificationScheduler.removeLegacyBehaviorReminders()

        let now = Date.now
        let expired = history.expireScheduledEvents(before: now, gracePeriod: ReminderTiming.expirationGracePeriod)
        var rollingFrom = date
        var rollingBehaviors = behaviors
        var compensationCandidates = compensation

        if !expired.isEmpty {
            let compensationDate = now.addingTimeInterval(ReminderTiming.compensationDelay)
            rollingFrom = max(rollingFrom ?? compensationDate, compensationDate)
            let expiredBehaviors = Set(expired.map(\.behavior))
            if let currentRollingBehaviors = rollingBehaviors {
                rollingBehaviors = currentRollingBehaviors.union(expiredBehaviors)
            } else {
                rollingBehaviors = expiredBehaviors
            }
            compensationCandidates += expired.compactMap { compensationCandidate(for: $0, dueAt: compensationDate) }
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
            _ = history.updateStatus(for: eventID, to: .cancelled, at: now)
        }
        await notificationScheduler.removeBehaviorReminders(for: plan.eventIDsToCancel)

        var pendingIDs = await notificationScheduler.pendingBehaviorEventIDs()
        var desiredIDs = Set<UUID>()
        for planned in plan.reminders {
            let event: ReminderEvent
            if let eventID = planned.eventID, let existing = history.event(for: eventID) {
                event = existing
            } else {
                event = history.recordScheduled(
                    behavior: planned.candidate.behavior,
                    context: context(for: planned.candidate.mode),
                    dueAt: planned.candidate.dueAt,
                    now: now
                )
            }
            desiredIDs.insert(event.id)
            guard !pendingIDs.contains(event.id) else { continue }
            do {
                try await notificationScheduler.schedule(event: event)
                pendingIDs.insert(event.id)
            } catch {
                _ = history.updateStatus(for: event.id, to: .cancelled, at: now)
            }
        }
        await notificationScheduler.removeStaleBehaviorReminders(keeping: desiredIDs)

        do {
            try await notificationScheduler.scheduleSleepReminderIfNeeded(
                for: configuration.schedule,
                leadTime: configuration.sleepReminderLeadTime,
                now: now
            )
        } catch {
            // Notifications may be unavailable without preventing the UI from opening.
        }
    }

    private func handle(_ action: ReminderAction) {
        switch action {
        case let .delivered(eventID, date):
            guard history.updateStatus(for: eventID, to: .delivered, at: date), let event = history.event(for: eventID) else { return }
            if !toastReminders.contains(where: { $0.id == event.id }) {
                toastReminders.append(event)
            }
            scheduleToastExpiration(for: event)
            Task { await refresh() }
        case let .opened(eventID, date):
            guard let event = history.event(for: eventID), !event.status.isTerminal else { return }
            if event.timestamp.addingTimeInterval(ReminderTiming.expirationGracePeriod) <= date {
                _ = history.updateStatus(for: eventID, to: .expired, at: date)
                showExpiredToast()
                Task { await refresh() }
                return
            }
            if event.status == .scheduled { _ = history.updateStatus(for: eventID, to: .delivered, at: date) }
            removeToast(for: eventID)
            fullScreenReminder = history.event(for: eventID)
        case let .acknowledged(eventID, _):
            acknowledge(eventID: eventID)
        case let .skipped(eventID, _):
            skip(eventID: eventID)
        }
    }

    private func scheduleToastExpiration(for event: ReminderEvent) {
        cancelToastExpiration(for: event.id)
        let delay = max(0, event.timestamp.addingTimeInterval(ReminderTiming.expirationGracePeriod).timeIntervalSinceNow)
        toastExpirationTasks[event.id] = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self else { return }
            self.removeToast(for: event.id)
            await self.refresh()
        }
    }

    private func cancelToastExpiration(for eventID: UUID) {
        toastExpirationTasks.removeValue(forKey: eventID)?.cancel()
    }

    private func removeToast(for eventID: UUID) {
        toastReminders.removeAll { $0.id == eventID }
        cancelToastExpiration(for: eventID)
    }

    private func removePrompt(for eventID: UUID) {
        removeToast(for: eventID)
        if fullScreenReminder?.id == eventID { fullScreenReminder = nil }
    }

    private func showExpiredToast() {
        expiredToastTask?.cancel()
        isShowingExpiredReminderToast = true
        expiredToastTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(ReminderTiming.expiredToastPresentationDuration)) } catch { return }
            self?.isShowingExpiredReminderToast = false
            self?.expiredToastTask = nil
        }
    }

    private func compensationCandidate(for event: ReminderEvent, dueAt: Date) -> ReminderCandidate? {
        let mode: DailyMode = event.context == .work ? .work : .idle
        return ReminderCandidate(behavior: event.behavior, mode: mode, dueAt: dueAt)
    }

    private func context(for mode: DailyMode) -> ReminderContext {
        mode == .work ? .work : .idle
    }
}
