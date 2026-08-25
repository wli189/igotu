import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private static let nextReminderIdentifier = "next-reminder"
    private static let sleepReminderIdentifier = "sleep-reminder"
    private static let sleepReminderLeadTime: TimeInterval = 30 * 60
    private static let reminderCategoryIdentifier = "wellness-reminder"
    private static let acknowledgeActionIdentifier = "acknowledge-reminder"
    private static let skipActionIdentifier = "skip-reminder"
    private static let eventIDKey = "eventID"

    private let center: UNUserNotificationCenter
    private var history: ReminderHistoryStore?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
    }

    func configure(history: ReminderHistoryStore) {
        self.history = history
        center.delegate = self

        let actions = [
            UNNotificationAction(
                identifier: Self.acknowledgeActionIdentifier,
                title: "Done",
                options: []
            ),
            UNNotificationAction(
                identifier: Self.skipActionIdentifier,
                title: "Skip",
                options: []
            )
        ]
        let category = UNNotificationCategory(
            identifier: Self.reminderCategoryIdentifier,
            actions: actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
    }

    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(_ candidate: ReminderCandidate) async throws -> UUID? {
        await cancelExistingPendingReminder()

        let event = history?.recordScheduled(
            behavior: candidate.behavior,
            context: reminderContext(for: candidate.mode),
            dueAt: candidate.dueAt
        )

        let content = UNMutableNotificationContent()
        content.title = candidate.behavior.title
        content.body = message(for: candidate.behavior)
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryIdentifier
        var userInfo: [AnyHashable: Any] = [
            "behavior": candidate.behavior.rawValue,
            "mode": modeKey(for: candidate.mode)
        ]
        if let event {
            userInfo[Self.eventIDKey] = event.id.uuidString
        }
        content.userInfo = userInfo

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

        do {
            try await center.add(request)
            return event?.id
        } catch {
            if let event {
                history?.updateStatus(for: event.id, to: .cancelled)
            }
            throw error
        }
    }

    func scheduleIfNeeded(_ candidate: ReminderCandidate) async throws -> UUID? {
        let pendingRequests = await center.pendingNotificationRequests()
        guard let pendingRequest = pendingRequests.first(where: {
            $0.identifier == Self.nextReminderIdentifier
        }) else {
            return try await schedule(candidate)
        }

        let isCurrentCandidate =
            pendingRequest.content.userInfo["behavior"] as? String == candidate.behavior.rawValue
            && pendingRequest.content.userInfo["mode"] as? String == modeKey(for: candidate.mode)

        guard !isCurrentCandidate else {
            return eventID(from: pendingRequest.content.userInfo)
        }

        return try await schedule(candidate)
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

    func cancelPendingReminder() async {
        await cancelExistingPendingReminder()
    }

    func removePendingReminder() {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.nextReminderIdentifier]
        )
    }

    func cancelSleepReminder() {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.sleepReminderIdentifier]
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        updateEventStatus(
            from: notification.request.content.userInfo,
            to: .delivered
        )
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let status: ReminderEventStatus

        switch response.actionIdentifier {
        case Self.acknowledgeActionIdentifier:
            status = .acknowledged
        case Self.skipActionIdentifier, UNNotificationDismissActionIdentifier:
            status = .skipped
        case UNNotificationDefaultActionIdentifier:
            status = .delivered
        default:
            completionHandler()
            return
        }

        updateEventStatus(
            from: response.notification.request.content.userInfo,
            to: status
        )
        completionHandler()
    }

    private func cancelExistingPendingReminder() async {
        let pendingRequests = await center.pendingNotificationRequests()
        if let pendingRequest = pendingRequests.first(where: {
            $0.identifier == Self.nextReminderIdentifier
        }), let eventID = eventID(from: pendingRequest.content.userInfo) {
            history?.updateStatus(for: eventID, to: .cancelled)
        }

        center.removePendingNotificationRequests(
            withIdentifiers: [Self.nextReminderIdentifier]
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

    private func reminderContext(for mode: DailyMode) -> ReminderContext {
        switch mode {
        case .work: return .work
        case .idle: return .idle
        case .sleeping: return .idle
        }
    }

    private func updateEventStatus(
        from userInfo: [AnyHashable: Any],
        to status: ReminderEventStatus
    ) {
        guard let eventID = eventID(from: userInfo) else { return }
        history?.updateStatus(for: eventID, to: status)
    }

    private func eventID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard
            let value = userInfo[Self.eventIDKey] as? String,
            let eventID = UUID(uuidString: value)
        else {
            return nil
        }

        return eventID
    }
}
