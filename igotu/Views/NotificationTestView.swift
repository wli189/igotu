import SwiftUI
import Combine

struct NotificationTestView: View {
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var testNotifications: [ScheduledTestNotification] = []

    private let refreshTimer = Timer.publish(
        every: 5,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Form {
                Section("Temporary notification") {
                    ForEach(Behavior.allCases) { behavior in
                        Button {
                            scheduleTestNotification(for: behavior)
                        } label: {
                            Label(
                                "\(behavior.title) in 1 minute",
                                systemImage: behavior.icon
                            )
                        }
                        .accessibilityIdentifier("\(behavior.title) in 1 minute")
                        .disabled(isWorking)
                    }

                    Button {
                        scheduleTestSleepReminder()
                    } label: {
                        Label("Wind Down in 1 minute", systemImage: "moon.zzz.fill")
                    }
                    .accessibilityIdentifier("Wind Down in 1 minute")
                    .disabled(isWorking)

                    Button(role: .destructive) {
                        clearTestNotifications()
                    } label: {
                        Label("Clear test notifications", systemImage: "trash")
                    }
                    .disabled(isWorking)
                }

                Section("Scheduled tests (\(testNotifications.count))") {
                    if testNotifications.isEmpty {
                        Text("No pending test notifications")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(testNotifications) { notification in
                            HStack(spacing: 12) {
                                Label(
                                    notification.kind.title,
                                    systemImage: notification.kind.icon
                                )

                                Spacer(minLength: 8)

                                Text(
                                    countdown(
                                        to: notification.fireDate,
                                        now: timeline.date
                                    )
                                )
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            refreshTestNotifications()
        }
        .onReceive(refreshTimer) { _ in
            refreshTestNotifications()
        }
        .navigationTitle("Testing")
    }

    private func scheduleTestNotification(for behavior: Behavior) {
        isWorking = true
        statusMessage = nil

        Task {
            let didSchedule = await reminderCoordinator.scheduleTestNotification(
                for: behavior
            )
            isWorking = false
            statusMessage = didSchedule
                ? "Test notification scheduled."
                : "Notifications are not enabled."
            refreshTestNotifications()
        }
    }

    private func clearTestNotifications() {
        isWorking = true

        Task {
            await reminderCoordinator.clearTestNotifications()
            isWorking = false
            statusMessage = "Test notifications cleared."
            refreshTestNotifications()
        }
    }

    private func scheduleTestSleepReminder() {
        isWorking = true
        statusMessage = nil

        Task {
            let didSchedule = await reminderCoordinator.scheduleTestSleepReminder()
            isWorking = false
            statusMessage = didSchedule
                ? "Test notification scheduled."
                : "Notifications are not enabled."
            refreshTestNotifications()
        }
    }

    private func refreshTestNotifications() {
        Task {
            testNotifications = await reminderCoordinator.pendingTestNotifications()
        }
    }

    private func countdown(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSince(now))))

        if seconds >= 60 {
            return "in \(seconds / 60)m \(seconds % 60)s"
        }

        return "in \(seconds)s"
    }
}
