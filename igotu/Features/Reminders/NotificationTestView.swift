import SwiftUI
import Combine
import IgotuCore

struct NotificationTestView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var testNotifications: [ScheduledTestNotification] = []
    @AppStorage("notificationTest.delaySeconds")
    private var delaySeconds = Int(ReminderTiming.testNotificationDelay)
    @AppStorage("notificationTest.expirationSeconds")
    private var expirationSeconds = Int(ReminderTiming.testExpirationGracePeriod)
    @AppStorage("notificationTest.repeatSeconds")
    private var repeatSeconds = Int(ReminderTiming.testRepeatDelay)

    private let refreshTimer = Timer.publish(
        every: 5,
        on: .main,
        in: .common
    ).autoconnect()

    private var testTiming: ReminderTestTiming {
        ReminderTestTiming(
            notificationDelay: TimeInterval(delaySeconds),
            expirationGracePeriod: TimeInterval(expirationSeconds),
            repeatDelay: TimeInterval(repeatSeconds)
        )
    }

    var body: some View {
        let accent = ThemeColorService().currentColor(for: configuration.schedule)

        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Form {
                Section("Timing") {
                    timingStepper(
                        title: "First alert",
                        value: $delaySeconds,
                        range: 1 ... 120,
                        accessibilityIdentifier: "Test first alert delay"
                    )
                    timingStepper(
                        title: "Visible duration",
                        value: $expirationSeconds,
                        range: 1 ... 300,
                        accessibilityIdentifier: "Test visible duration"
                    )
                    timingStepper(
                        title: "Repeat delay",
                        value: $repeatSeconds,
                        range: 1 ... 300,
                        accessibilityIdentifier: "Test repeat delay"
                    )
                }

                Section("Temporary notification") {
                    ForEach(Behavior.allCases) { behavior in
                        Button {
                            scheduleTestNotification(for: behavior)
                        } label: {
                            Label(
                                behavior.title,
                                systemImage: behavior.icon
                            )
                        }
                        .accessibilityIdentifier("Schedule \(behavior.title) test")
                        .disabled(isWorking)
                    }

                    Button {
                        scheduleTestSleepReminder()
                    } label: {
                        Label("Wind Down", systemImage: "moon.zzz.fill")
                    }
                    .accessibilityIdentifier("Schedule Wind Down test")
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
        .scrollContentBackground(.hidden)
        .background {
            AmbientBackground(color: accent)
        }
        .tint(accent)
        .onAppear {
            refreshTestNotifications()
        }
        .onReceive(refreshTimer) { _ in
            refreshTestNotifications()
        }
        .navigationTitle("Testing")
    }

    private func timingStepper(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        accessibilityIdentifier: String
    ) -> some View {
        HStack {
            Text(title)

            Spacer(minLength: 12)

            HStack(spacing: 0) {
                Button {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 36, height: 36)
                }
                .disabled(value.wrappedValue == range.lowerBound)
                .accessibilityLabel("Decrease \(title)")
                .accessibilityIdentifier("\(accessibilityIdentifier) minus")

                Text("\(value.wrappedValue)")
                    .monospacedDigit()
                    .frame(minWidth: 32)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("\(accessibilityIdentifier) value")

                Button {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                }
                .disabled(value.wrappedValue == range.upperBound)
                .accessibilityLabel("Increase \(title)")
                .accessibilityIdentifier("\(accessibilityIdentifier) plus")
            }
            .buttonStyle(.borderless)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func scheduleTestNotification(for behavior: Behavior) {
        isWorking = true
        statusMessage = nil

        Task {
            let didSchedule = await reminderCoordinator.scheduleTestNotification(
                for: behavior,
                timing: testTiming
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
            let didSchedule = await reminderCoordinator.scheduleTestSleepReminder(
                after: testTiming.notificationDelay
            )
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

#Preview {
    let configuration = PreviewSupport.configuration(named: "notification-test")
    let history = PreviewSupport.history(named: "notification-test")

    NavigationStack {
        NotificationTestView()
    }
    .environmentObject(configuration)
    .environmentObject(
        PreviewSupport.reminderCoordinator(
            configuration: configuration,
            history: history
        )
    )
}
