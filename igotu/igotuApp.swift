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
    private let notificationScheduler = NotificationScheduler()

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
        do {
            guard try await notificationScheduler.requestPermission() else {
                notificationScheduler.cancelPendingReminder()
                return
            }

            let mode = modeManager.currentMode(for: configuration.schedule)
            let rules: [ReminderRule]

            switch mode {
            case .sleeping:
                notificationScheduler.cancelPendingReminder()
                return
            case .work:
                rules = configuration.workReminders
            case .idle:
                rules = configuration.idleReminders
            }

            guard let candidate = engine.nextReminder(from: ReminderEngineInput(
                now: .now,
                mode: mode,
                rules: rules,
                recentEvents: []
            )) else {
                notificationScheduler.cancelPendingReminder()
                return
            }

            if replacePending {
                try await notificationScheduler.schedule(candidate)
            } else {
                try await notificationScheduler.scheduleIfNeeded(candidate)
            }
        } catch {
            // Notification permission and scheduling failures should not prevent the app from opening.
        }
    }
}
