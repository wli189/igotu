import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    private static let nextReminderIdentifier = "next-reminder"
    private static let sleepReminderIdentifier = "sleep-reminder"
    private static let sleepReminderLeadTime: TimeInterval = 30 * 60

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(_ candidate: ReminderCandidate) async throws {
        let content = UNMutableNotificationContent()
        content.title = candidate.behavior.title
        content.body = message(for: candidate.behavior)
        content.sound = .default
        content.userInfo = [
            "behavior": candidate.behavior.rawValue,
            "mode": modeKey(for: candidate.mode)
        ]

        let secondsUntilReminder = max(
            1,
            candidate.dueAt.timeIntervalSinceNow
        )
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: secondsUntilReminder,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.nextReminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(
            withIdentifiers: [Self.nextReminderIdentifier]
        )
        try await center.add(request)
    }

    func scheduleIfNeeded(_ candidate: ReminderCandidate) async throws {
        let pendingRequests = await center.pendingNotificationRequests()
        guard let pendingRequest = pendingRequests.first(where: {
            $0.identifier == Self.nextReminderIdentifier
        }) else {
            try await schedule(candidate)
            return
        }

        let isCurrentCandidate =
            pendingRequest.content.userInfo["behavior"] as? String == candidate.behavior.rawValue
            && pendingRequest.content.userInfo["mode"] as? String == modeKey(for: candidate.mode)

        guard !isCurrentCandidate else {
            return
        }

        try await schedule(candidate)
    }

    func scheduleSleepReminderIfNeeded(
        for schedule: DailySchedule,
        now: Date = .now
    ) async throws {
        guard let sleepStart = schedule.nextSleepStart(after: now) else {
            cancelSleepReminder()
            return
        }

        let pendingRequests = await center.pendingNotificationRequests()
        guard let pendingRequest = pendingRequests.first(where: {
            $0.identifier == Self.sleepReminderIdentifier
        }) else {
            try await scheduleSleepReminder(at: sleepStart, now: now)
            return
        }

        let scheduledSleepStart = pendingRequest.content.userInfo["sleepStart"] as? TimeInterval
        guard scheduledSleepStart == sleepStart.timeIntervalSince1970 else {
            try await scheduleSleepReminder(at: sleepStart, now: now)
            return
        }
    }

    func cancelPendingReminder() {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.nextReminderIdentifier]
        )
    }

    func cancelSleepReminder() {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.sleepReminderIdentifier]
        )
    }

    private func scheduleSleepReminder(at sleepStart: Date, now: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Wind Down"
        content.body = "Your scheduled sleep time is in 30 minutes."
        content.sound = .default
        content.userInfo = [
            "kind": "sleep",
            "sleepStart": sleepStart.timeIntervalSince1970
        ]

        let reminderDate = sleepStart.addingTimeInterval(-Self.sleepReminderLeadTime)
        let secondsUntilReminder = max(
            1,
            reminderDate.timeIntervalSince(now)
        )
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: secondsUntilReminder,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.sleepReminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(
            withIdentifiers: [Self.sleepReminderIdentifier]
        )
        try await center.add(request)
    }

    private func message(for behavior: Behavior) -> String {
        switch behavior {
        case .hydration:
            return "Take a moment to drink some water."
        case .standUp:
            return "Stand up and stretch for a moment."
        case .movement:
            return "Take a short walk or move around."
        }
    }

    private func modeKey(for mode: DailyMode) -> String {
        switch mode {
        case .sleeping: return "sleeping"
        case .work: return "work"
        case .idle: return "idle"
        }
    }
}
