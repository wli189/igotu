import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private static let legacyNextReminderIdentifier = "next-reminder"
    private static let reminderIdentifierPrefix = WellnessReminderNotification.identifierPrefix
    private static let sleepReminderIdentifier = "sleep-reminder"
    private static let reminderCategoryIdentifier = WellnessReminderNotification.categoryIdentifier
    private static let acknowledgeActionIdentifier = "acknowledge-reminder"
    private static let skipActionIdentifier = "skip-reminder"

    private enum SchedulerError: Error {
        case historyNotConfigured
    }

    private let center: UNUserNotificationCenter
    private var history: ReminderHistoryStore?
    private var onReminderAction: (() -> Void)?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
    }

    func configure(
        history: ReminderHistoryStore,
        onReminderAction: (() -> Void)? = nil
    ) {
        self.history = history
        self.onReminderAction = onReminderAction
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

    func pendingReminders() async -> [ScheduledReminder] {
        await pendingDailyRequests().compactMap { request in
            ScheduledReminder(request: request)
        }
    }

    func reconcile(
        _ candidates: [ReminderCandidate],
        replacingExisting: Bool
    ) async throws -> [ScheduledReminder] {
        let pendingRequests = await pendingDailyRequests()

        if replacingExisting {
            await cancel(requests: pendingRequests)
        } else {
            let desiredKeys = Set(candidates.map {
                reminderKey(behavior: $0.behavior, mode: $0.mode)
            })
            let staleRequests = pendingRequests.filter { request in
                guard let scheduled = ScheduledReminder(request: request) else {
                    return true
                }

                return !desiredKeys.contains(reminderKey(
                    behavior: scheduled.candidate.behavior,
                    mode: scheduled.candidate.mode
                ))
            }
            await cancel(requests: staleRequests)
        }

        var scheduledReminders: [ScheduledReminder] = []

        for candidate in candidates {
            if let scheduledReminder = try await scheduleIfNeeded(candidate) {
                scheduledReminders.append(scheduledReminder)
            }
        }

        return scheduledReminders.sorted { first, second in
            if first.candidate.dueAt != second.candidate.dueAt {
                return first.candidate.dueAt < second.candidate.dueAt
            }

            return first.candidate.behavior.reminderPriority
                < second.candidate.behavior.reminderPriority
        }
    }

    func scheduleIfNeeded(_ candidate: ReminderCandidate) async throws -> ScheduledReminder? {
        let pendingRequests = await pendingDailyRequests()
        let matchingRequests = pendingRequests.compactMap { request -> (
            request: UNNotificationRequest,
            reminder: ScheduledReminder
        )? in
            guard let reminder = ScheduledReminder(request: request) else {
                return nil
            }

            guard reminder.candidate.behavior == candidate.behavior,
                  reminder.candidate.mode == candidate.mode else {
                return nil
            }

            return (request: request, reminder: reminder)
        }

        let currentMatch = matchingRequests.first { match in
            match.reminder.candidate == candidate
        }

        let staleRequests = matchingRequests.filter { match in
            guard let currentMatch else { return true }
            return match.request.identifier != currentMatch.request.identifier
        }.map(\.request)
        await cancel(requests: staleRequests)

        guard let currentMatch else {
            return try await schedule(candidate)
        }

        if
            currentMatch.request.identifier != Self.legacyNextReminderIdentifier,
            let status = history?.status(for: currentMatch.reminder.eventID),
            !status.isTerminal
        {
            return currentMatch.reminder
        }

        await cancel(requests: [currentMatch.request])
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

    func cancelPendingReminders() async {
        let requests = await pendingDailyRequests()
        await cancel(requests: requests)
    }

    func removePendingReminders(for eventIDs: Set<UUID>) async {
        let pendingRequests = await pendingDailyRequests()
        let requests = pendingRequests.filter { request in
            guard let eventID = eventID(from: request.content.userInfo) else {
                return false
            }

            return eventIDs.contains(eventID)
        }

        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier)
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
        _ = updateEventStatus(
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
            center.removeDeliveredNotifications(
                withIdentifiers: [response.notification.request.identifier]
            )
        case Self.skipActionIdentifier, UNNotificationDismissActionIdentifier:
            status = .skipped
            center.removeDeliveredNotifications(
                withIdentifiers: [response.notification.request.identifier]
            )
        case UNNotificationDefaultActionIdentifier:
            status = .delivered
        default:
            completionHandler()
            return
        }

        guard updateEventStatus(
            from: response.notification.request.content.userInfo,
            to: status
        ) != nil else {
            completionHandler()
            return
        }

        onReminderAction?()
        completionHandler()
    }

    private func schedule(_ candidate: ReminderCandidate) async throws -> ScheduledReminder? {
        guard let history else {
            throw SchedulerError.historyNotConfigured
        }

        let event = history.recordScheduled(
            behavior: candidate.behavior,
            context: reminderContext(for: candidate.mode),
            dueAt: candidate.dueAt
        )

        let content = UNMutableNotificationContent()
        content.title = candidate.behavior.title
        content.subtitle = candidate.mode.title + " routine"
        content.body = candidate.behavior.reminderMessage
        content.sound = .default
        content.threadIdentifier = Self.reminderCategoryIdentifier
        content.categoryIdentifier = Self.reminderCategoryIdentifier
        content.userInfo = ReminderNotificationPayload(
            eventID: event.id,
            candidate: candidate
        ).userInfo

        let secondsUntilReminder = max(
            1,
            candidate.dueAt.timeIntervalSinceNow
        )
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: secondsUntilReminder,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier(for: event.id),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return ScheduledReminder(eventID: event.id, candidate: candidate)
        } catch {
            history.updateStatus(for: event.id, to: .cancelled)
            throw error
        }
    }

    private func scheduleSleepReminder(at sleepStart: Date, now: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Wind Down"
        let leadTimeMinutes = Int(ReminderTiming.sleepReminderLeadTime / 60)
        content.body = "Your scheduled sleep time is in \(leadTimeMinutes) minutes."
        content.sound = .default
        content.userInfo = [
            "kind": "sleep",
            "sleepStart": sleepStart.timeIntervalSince1970
        ]

        let reminderDate = sleepStart.addingTimeInterval(-ReminderTiming.sleepReminderLeadTime)
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

    private func reminderContext(for mode: DailyMode) -> ReminderContext {
        switch mode {
        case .work: return .work
        case .idle: return .idle
        case .sleeping: return .idle
        }
    }

    private func pendingDailyRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests().filter {
            Self.isDailyReminderIdentifier($0.identifier)
        }
    }

    private func cancel(requests: [UNNotificationRequest]) async {
        guard !requests.isEmpty else { return }

        for request in requests {
            if let eventID = eventID(from: request.content.userInfo) {
                history?.updateStatus(for: eventID, to: .cancelled)
            }
        }

        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier)
        )
    }

    private func reminderKey(behavior: Behavior, mode: DailyMode) -> String {
        "\(behavior.rawValue):\(mode.key)"
    }

    private func updateEventStatus(
        from userInfo: [AnyHashable: Any],
        to status: ReminderEventStatus
    ) -> UUID? {
        guard let eventID = eventID(from: userInfo) else { return nil }
        history?.updateStatus(for: eventID, to: status)
        return eventID
    }

    private func eventID(from userInfo: [AnyHashable: Any]) -> UUID? {
        ReminderNotificationPayload.eventID(from: userInfo)
    }

    private static func reminderIdentifier(for eventID: UUID) -> String {
        WellnessReminderNotification.identifier(for: eventID)
    }

    private static func isDailyReminderIdentifier(_ identifier: String) -> Bool {
        identifier == legacyNextReminderIdentifier
            || identifier.hasPrefix(reminderIdentifierPrefix)
    }
}
