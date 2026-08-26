//
//  igotuApp.swift
//  igotu
//
//  Created by Brian Li on 8/17/26.
//

import SwiftUI

@main
struct igotuApp: App {
    @StateObject private var configuration: AppConfigurationStore
    @Environment(\.scenePhase) private var scenePhase

    private let history: ReminderHistoryStore
    private let reminderCoordinator: ReminderCoordinator

    init() {
        let configuration = AppConfigurationStore()
        let history = ReminderHistoryStore()
        let modeManager = DailyModeManager()
        let engine = ReminderEngine()
        let notificationScheduler = NotificationScheduler()
        let liveActivityScheduler = LiveActivityScheduler()

        _configuration = StateObject(wrappedValue: configuration)
        self.history = history
        self.reminderCoordinator = ReminderCoordinator(
            configuration: configuration,
            modeManager: modeManager,
            engine: engine,
            history: history,
            notificationScheduler: notificationScheduler,
            liveActivityScheduler: liveActivityScheduler
        )
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
                await reminderCoordinator.refresh(replacePending: true)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, configuration.hasCompletedSetup else { return }

                Task {
                    await reminderCoordinator.refresh(replacePending: false)
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
            await reminderCoordinator.refresh(replacePending: true)
        }
    }
}
