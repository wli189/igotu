import Foundation
import Combine

@MainActor
final class ReminderCoordinator: ObservableObject {
    private let configuration: AppConfigurationStore
    private let planner: ReminderPlanner
    private let history: ReminderHistoryStore
    private let notificationScheduler: NotificationScheduler

    private var refreshInProgress = false
    private var refreshQueued = false

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
        if refreshInProgress {
            refreshQueued = true
            return
        }

        refreshInProgress = true
        defer { refreshInProgress = false }

        repeat {
            refreshQueued = false
            await performRefresh()
        } while refreshQueued
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

    private func performRefresh() async {
        guard configuration.hasCompletedSetup else { return }

        await notificationScheduler.removeLegacyBehaviorReminders()
        _ = await notificationScheduler.requestPermissionIfNeeded()

        let now = Date.now
        history.expireScheduledEvents(
            before: now,
            gracePeriod: ReminderTiming.expirationGracePeriod
        )

        let plan = planner.plan(
            for: configuration.schedule,
            workRules: configuration.workReminders,
            idleRules: configuration.idleReminders,
            events: history.events,
            now: now
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
        case let .acknowledged(eventID, date):
            history.updateStatus(for: eventID, to: .acknowledged, at: date)
        case let .skipped(eventID, date):
            history.updateStatus(for: eventID, to: .skipped, at: date)
        }

        Task { [weak self] in
            await self?.refresh()
        }
    }

    private func context(for mode: DailyMode) -> ReminderContext {
        switch mode {
        case .work: return .work
        case .idle, .sleeping: return .idle
        }
    }
}
