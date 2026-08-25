//
//  igotuApp.swift
//  igotu
//
//  Created by Brian Li on 8/17/26.
//

import SwiftUI

@main
struct igotuApp: App {
    @StateObject private var configuration = AppConfigurationStore()
    @Environment(\.scenePhase) private var scenePhase

    private let modeManager = DailyModeManager()
    private let engine = ReminderEngine()
    private let history: ReminderHistoryStore
    private let notificationScheduler: NotificationScheduler
    private let liveActivityScheduler: LiveActivityScheduler

    init() {
        let history = ReminderHistoryStore()
        let notificationScheduler = NotificationScheduler()
        let liveActivityScheduler = LiveActivityScheduler()

        self.history = history
        self.notificationScheduler = notificationScheduler
        self.liveActivityScheduler = liveActivityScheduler
        notificationScheduler.configure(history: history)
        liveActivityScheduler.configure(history: history)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if configuration.hasCompletedSetup {
                    TodayView()
                } else {
                    SetUpView()
                }
            }
            .environmentObject(configuration)
            .environmentObject(history)
            .task(id: configuration.hasCompletedSetup) {
                guard configuration.hasCompletedSetup else { return }
                await refreshNotification(replacePending: true)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, configuration.hasCompletedSetup else { return }

                Task {
                    await refreshNotification(replacePending: false)
                }
            }
            .onChange(of: configuration.schedule) { _, _ in
                refreshNotificationTask()
            }
            .onChange(of: configuration.workReminders) { _, _ in
                refreshNotificationTask()
            }
            .onChange(of: configuration.idleReminders) { _, _ in
                refreshNotificationTask()
            }
        }
    }

    private func refreshNotificationTask() {
        guard configuration.hasCompletedSetup else { return }

        Task {
            await refreshNotification(replacePending: true)
        }
    }

    private func refreshNotification(replacePending: Bool) async {
        let didSynchronizeActions = liveActivityScheduler.synchronizeActions()
        if didSynchronizeActions {
            notificationScheduler.removePendingReminder()
        }

        do {
            _ = try? await notificationScheduler.requestPermission()

            let mode = modeManager.currentMode(for: configuration.schedule)
            let rules: [ReminderRule]

            switch mode {
            case .sleeping:
                await notificationScheduler.cancelPendingReminder()
                notificationScheduler.cancelSleepReminder()
                await liveActivityScheduler.endAll()
                return
            case .work:
                rules = configuration.workReminders
            case .idle:
                rules = configuration.idleReminders
            }

            try? await notificationScheduler.scheduleSleepReminderIfNeeded(
                for: configuration.schedule
            )

            guard let candidate = engine.nextReminder(from: ReminderEngineInput(
                now: .now,
                mode: mode,
                rules: rules,
                recentEvents: history.recentEvents(
                    since: .now.addingTimeInterval(-30 * 24 * 60 * 60)
                )
            )) else {
                await notificationScheduler.cancelPendingReminder()
                await liveActivityScheduler.endAll()
                return
            }

            if replacePending {
                await liveActivityScheduler.endAll()
            }

            let eventID: UUID?
            do {
                if replacePending {
                    eventID = try await notificationScheduler.schedule(candidate)
                } else {
                    eventID = try await notificationScheduler.scheduleIfNeeded(candidate)
                }
            } catch {
                // A Live Activity can still work when local notification scheduling fails.
                eventID = history.recordScheduled(
                    behavior: candidate.behavior,
                    context: reminderContext(for: mode),
                    dueAt: candidate.dueAt
                ).id
            }

            if let eventID {
                await liveActivityScheduler.startIfNeeded(
                    for: candidate,
                    eventID: eventID
                )
            }
        } catch {
            // Scheduling failures should not prevent the app from opening.
        }
    }

    private func reminderContext(for mode: DailyMode) -> ReminderContext {
        switch mode {
        case .work:
            return .work
        case .idle, .sleeping:
            return .idle
        }
    }
}
