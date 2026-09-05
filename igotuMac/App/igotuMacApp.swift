import SwiftUI
import IgotuCore

@main
struct igotuMacApp: App {
    @StateObject private var configuration: MacConfigurationStore
    @Environment(\.scenePhase) private var scenePhase
    private let history: MacReminderHistoryStore
    private let reminderCoordinator: MacReminderCoordinator

    init() {
        let configuration = MacConfigurationStore()
        let history = MacReminderHistoryStore()
        let reminderCoordinator = MacReminderCoordinator(
            configuration: configuration,
            history: history,
            notificationScheduler: MacNotificationScheduler()
        )
        _configuration = StateObject(wrappedValue: configuration)
        self.history = history
        self.reminderCoordinator = reminderCoordinator
    }

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environmentObject(configuration)
                .environmentObject(history)
                .environmentObject(reminderCoordinator)
                .task(id: configuration.hasCompletedSetup) {
                    guard configuration.hasCompletedSetup else { return }
                    await reminderCoordinator.refresh()
                }
                .onChange(of: configuration.schedule) { _, _ in refreshReminders() }
                .onChange(of: configuration.workReminders) { _, _ in refreshReminders() }
                .onChange(of: configuration.idleReminders) { _, _ in refreshReminders() }
                .onChange(of: configuration.sleepReminderLeadTime) { _, _ in refreshReminders() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    refreshReminders()
                }
                .overlay(alignment: .top) {
                    if reminderCoordinator.isShowingExpiredReminderToast {
                        MacExpiredReminderToast()
                            .padding(.top, 10)
                    } else if let event = reminderCoordinator.toastReminders.first {
                        MacReminderToast(event: event) {
                            reminderCoordinator.acknowledge(eventID: event.id)
                        } onSkip: {
                            reminderCoordinator.skip(eventID: event.id)
                        }
                        .padding(.top, 10)
                    }
                }
                .sheet(item: Binding(
                    get: { reminderCoordinator.fullScreenReminder },
                    set: { if $0 == nil { reminderCoordinator.dismissFullScreenReminder() } }
                )) { event in
                    MacReminderConfirmation(event: event)
                        .environmentObject(reminderCoordinator)
                }
        }
        .defaultSize(width: 1_120, height: 740)
        .windowResizability(.contentSize)

        Settings {
            Form {
                Text("Your schedule and reminders are stored on this Mac.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 420)
        }
    }

    private func refreshReminders() {
        guard configuration.hasCompletedSetup else { return }
        Task { await reminderCoordinator.refreshRollingFromNow() }
    }
}
