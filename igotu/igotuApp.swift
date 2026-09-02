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
        let reminderCoordinator = ReminderCoordinator(
            configuration: configuration,
            engine: ReminderEngine(),
            history: history,
            notificationScheduler: NotificationScheduler()
        )

        _configuration = StateObject(wrappedValue: configuration)
        self.history = history
        self.reminderCoordinator = reminderCoordinator
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if configuration.hasCompletedSetup {
                    MainTabView()
                } else {
                    NavigationStack {
                        SetUpView()
                    }
                }
            }
            .environmentObject(configuration)
            .environmentObject(history)
            .environmentObject(reminderCoordinator)
            .task(id: configuration.hasCompletedSetup) {
                guard configuration.hasCompletedSetup else { return }
                await reminderCoordinator.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }

                Task {
                    await reminderCoordinator.refresh()
                }
            }
            .onChange(of: configuration.schedule) { _, _ in
                refreshReminders()
            }
            .onChange(of: configuration.workReminders) { _, _ in
                refreshReminders()
            }
            .onChange(of: configuration.idleReminders) { _, _ in
                refreshReminders()
            }
            .onChange(of: configuration.sleepReminderLeadTime) { _, _ in
                refreshReminders()
            }
        }
    }

    private func refreshReminders() {
        guard configuration.hasCompletedSetup else { return }

        Task {
            await reminderCoordinator.refresh()
        }
    }
}
