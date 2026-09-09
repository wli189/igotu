//
//  igotuApp.swift
//  igotu
//
//  Created by Brian Li on 8/17/26.
//

import SwiftUI
import IgotuCore

@main
struct igotuApp: App {
    @StateObject private var configuration: AppConfigurationStore
    @Environment(\.scenePhase) private var scenePhase

    private let history: ReminderHistoryStore
    private let reminderCoordinator: ReminderCoordinator
    private let backgroundScheduler: ReminderBackgroundScheduler

    init() {
        let configuration = AppConfigurationStore()
        let history = ReminderHistoryStore()
        let reminderCoordinator = ReminderCoordinator(
            configuration: configuration,
            engine: ReminderEngine(),
            history: history,
            notificationScheduler: NotificationScheduler()
        )
        let backgroundScheduler = ReminderBackgroundScheduler {
            await reminderCoordinator.refresh()
        }
        backgroundScheduler.register()

        _configuration = StateObject(wrappedValue: configuration)
        self.history = history
        self.reminderCoordinator = reminderCoordinator
        self.backgroundScheduler = backgroundScheduler
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
                backgroundScheduler.scheduleNextRefresh()
                await reminderCoordinator.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    refreshReminders()
                case .inactive, .background:
                    guard configuration.hasCompletedSetup else { break }
                    backgroundScheduler.scheduleNextRefresh()

                    Task {
                        await reminderCoordinator.refresh()
                    }
                @unknown default:
                    break
                }
            }
            .onChange(of: configuration.schedule) { _, _ in
                refreshReminders(rolling: true)
            }
            .onChange(of: configuration.workReminders) { _, _ in
                refreshReminders(rolling: true)
            }
            .onChange(of: configuration.studyReminders) { _, _ in
                refreshReminders(rolling: true)
            }
            .onChange(of: configuration.idleReminders) { _, _ in
                refreshReminders(rolling: true)
            }
            .onChange(of: configuration.sleepReminderLeadTime) { _, _ in
                refreshReminders(rolling: true)
            }
        }
    }

    private func refreshReminders(rolling: Bool = false) {
        guard configuration.hasCompletedSetup else { return }

        backgroundScheduler.scheduleNextRefresh()

        Task {
            if rolling {
                await reminderCoordinator.refreshRollingFromNow()
            } else {
                await reminderCoordinator.refresh()
            }
        }
    }
}
