import Foundation

@MainActor
final class ReminderCoordinator {
    private let configuration: AppConfigurationStore
    private let modeManager: DailyModeManager
    private let engine: ReminderEngine
    private let history: ReminderHistoryStore
    private let notificationScheduler: NotificationScheduler
    private let liveActivityScheduler: LiveActivityScheduler
    private var refreshInProgress = false
    private var refreshQueued = false
    private var replacePendingQueued = false

    init(
        configuration: AppConfigurationStore,
        modeManager: DailyModeManager,
        engine: ReminderEngine,
        history: ReminderHistoryStore,
        notificationScheduler: NotificationScheduler,
        liveActivityScheduler: LiveActivityScheduler
    ) {
        self.configuration = configuration
        self.modeManager = modeManager
        self.engine = engine
        self.history = history
        self.notificationScheduler = notificationScheduler
        self.liveActivityScheduler = liveActivityScheduler

        notificationScheduler.configure(history: history) { [weak self] in
            self?.refreshAfterReminderAction()
        }
        liveActivityScheduler.configure(history: history)
    }

    func refresh(replacePending: Bool) async {
        if refreshInProgress {
            refreshQueued = true
            replacePendingQueued = replacePendingQueued || replacePending
            return
        }

        refreshInProgress = true
        defer { refreshInProgress = false }

        var shouldReplacePending = replacePending

        while true {
            refreshQueued = false
            replacePendingQueued = false
            await performRefresh(replacePending: shouldReplacePending)

            guard refreshQueued else { return }
            shouldReplacePending = replacePendingQueued
        }
    }

    private func performRefresh(replacePending: Bool) async {
        let liveActivityEventIDs = liveActivityScheduler.synchronizeActions()
        if !liveActivityEventIDs.isEmpty {
            await notificationScheduler.removePendingReminders(
                for: liveActivityEventIDs
            )
        }

        if replacePending {
            await liveActivityScheduler.endAll()
        }

        do {
            _ = try? await notificationScheduler.requestPermission()

            let mode = modeManager.currentMode(for: configuration.schedule)
            let rules: [ReminderRule]

            switch mode {
            case .sleeping:
                await notificationScheduler.cancelPendingReminders()
                notificationScheduler.cancelSleepReminder()
                await liveActivityScheduler.endAll()
                return
            case .work:
                rules = configuration.workReminders
            case .idle:
                rules = configuration.idleReminders
            }

            let now = Date.now
            try? await notificationScheduler.scheduleSleepReminderIfNeeded(
                for: configuration.schedule,
                now: now
            )
            history.expireScheduledEvents(before: now)

            let candidates = engine.nextReminders(from: ReminderEngineInput(
                now: now,
                mode: mode,
                rules: rules,
                recentEvents: history.recentEvents(
                    since: now.addingTimeInterval(-30 * 24 * 60 * 60),
                    now: now
                )
            ))

            let scheduledReminders = try await notificationScheduler.reconcile(
                candidates,
                replacingExisting: replacePending
            )

            guard let nextReminder = scheduledReminders.first else {
                await liveActivityScheduler.endAll()
                return
            }

            await liveActivityScheduler.startIfNeeded(
                for: nextReminder.candidate,
                eventID: nextReminder.eventID
            )
        } catch {
            // Scheduling failures should not prevent the app from opening.
        }
    }

    private func refreshAfterReminderAction() {
        guard configuration.hasCompletedSetup else { return }

        Task { [weak self] in
            await self?.refresh(replacePending: false)
        }
    }
}
