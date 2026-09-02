import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private enum Identifier {
        static let sleepReminder = "sleep-reminder"
        static let behaviorPrefix = "behavior-reminder."
        static let testPrefix = "test-reminder."
        static let legacyNextReminder = "next-reminder"
        static let legacyBehaviorPrefix = "wellness-reminder-"
    }

    private enum Category {
        static let behaviorReminder = "behavior-reminder"
        static let testReminder = "test-reminder"
        static let acknowledge = "acknowledge-reminder"
        static let skip = "skip-reminder"
    }

    private enum PayloadKey {
        static let kind = "kind"
        static let sleep = "sleep-reminder"
        static let test = "test-reminder"
        static let testBehavior = "testBehavior"
        static let testType = "testType"
        static let testSleepReminder = "sleep-reminder"
        static let testFireDate = "testFireDate"
        static let sleepLeadTime = "sleepLeadTime"
        static let sleepStart = "sleepStart"
    }

    private let center: UNUserNotificationCenter
    private var onAction: ((ReminderAction) -> Void)?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
    }

    func configure(onAction: @escaping (ReminderAction) -> Void) {
        self.onAction = onAction
        center.delegate = self

        let actions = [
            UNNotificationAction(
                identifier: Category.acknowledge,
                title: "Done",
                options: []
            ),
            UNNotificationAction(
                identifier: Category.skip,
                title: "Skip",
                options: []
            )
        ]
        let category = UNNotificationCategory(
            identifier: Category.behaviorReminder,
            actions: actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let testCategory = UNNotificationCategory(
            identifier: Category.testReminder,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category, testCategory])
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
        }

        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func pendingBehaviorEventIDs() async -> Set<UUID> {
        Set(await center.pendingNotificationRequests().compactMap { request in
            guard isBehaviorRequest(request) else { return nil }
            return ReminderNotificationPayload.eventID(from: request.content.userInfo)
        })
    }

    func removeLegacyBehaviorReminders() async {
        let requests = await center.pendingNotificationRequests().filter { request in
            request.identifier == Identifier.legacyNextReminder
                || request.identifier.hasPrefix(Identifier.legacyBehaviorPrefix)
        }

        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier)
        )
    }

    func scheduleTestNotification(
        for behavior: Behavior,
        after delay: TimeInterval = 60
    ) async throws {
        let fireDate = Date.now.addingTimeInterval(max(1, delay))
        let content = UNMutableNotificationContent()
        content.title = "Test: \(behavior.title)"
        content.body = "Temporary test notification."
        content.sound = .default
        content.categoryIdentifier = Category.testReminder
        content.threadIdentifier = Category.testReminder
        content.userInfo = [
            PayloadKey.kind: PayloadKey.test,
            "version": 1,
            PayloadKey.testType: "behavior",
            PayloadKey.testBehavior: behavior.rawValue,
            PayloadKey.testFireDate: fireDate.timeIntervalSince1970
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Identifier.testPrefix + UUID().uuidString,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func scheduleTestSleepReminder(after delay: TimeInterval = 60) async throws {
        let fireDate = Date.now.addingTimeInterval(max(1, delay))
        let content = UNMutableNotificationContent()
        content.title = "Test: Wind Down"
        content.body = "Temporary test sleep reminder."
        content.sound = .default
        content.categoryIdentifier = Category.testReminder
        content.threadIdentifier = Category.testReminder
        content.userInfo = [
            PayloadKey.kind: PayloadKey.test,
            "version": 1,
            PayloadKey.testType: PayloadKey.testSleepReminder,
            PayloadKey.testFireDate: fireDate.timeIntervalSince1970
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Identifier.testPrefix + UUID().uuidString,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func pendingTestNotifications() async -> [ScheduledTestNotification] {
        await center.pendingNotificationRequests().compactMap { request in
            guard
                request.identifier.hasPrefix(Identifier.testPrefix),
                request.content.userInfo[PayloadKey.kind] as? String == PayloadKey.test,
                let fireDate = testFireDate(from: request.content.userInfo)
            else {
                return nil
            }

            let kind: ScheduledTestNotification.Kind
            if let behaviorValue = request.content.userInfo[PayloadKey.testBehavior] as? String,
               let behavior = Behavior(rawValue: behaviorValue)
            {
                kind = .behavior(behavior)
            } else if request.content.userInfo[PayloadKey.testType] as? String
                == PayloadKey.testSleepReminder
            {
                kind = .sleepReminder
            } else {
                return nil
            }

            return ScheduledTestNotification(
                id: request.identifier,
                kind: kind,
                fireDate: fireDate
            )
        }
        .sorted { first, second in
            if first.fireDate != second.fireDate {
                return first.fireDate < second.fireDate
            }

            return first.id < second.id
        }
    }

    func removeTestNotifications() async {
        let requests = await center.pendingNotificationRequests().filter {
            $0.identifier.hasPrefix(Identifier.testPrefix)
        }
        let delivered = await center.deliveredNotifications().filter {
            $0.request.identifier.hasPrefix(Identifier.testPrefix)
        }

        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier)
        )
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.map { $0.request.identifier }
        )
    }

    func schedule(event: ReminderEvent) async throws {
        let content = UNMutableNotificationContent()
        content.title = event.behavior.title
        content.subtitle = "\(event.context.title) routine"
        content.body = event.behavior.reminderMessage
        content.sound = .default
        content.categoryIdentifier = Category.behaviorReminder
        content.threadIdentifier = Category.behaviorReminder
        content.userInfo = ReminderNotificationPayload(eventID: event.id).userInfo

        let secondsUntilReminder = max(
            1,
            event.timestamp.timeIntervalSinceNow
        )
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: secondsUntilReminder,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.behaviorIdentifier(for: event.id),
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func removeBehaviorReminders(for eventIDs: Set<UUID>) async {
        guard !eventIDs.isEmpty else { return }

        let requests = await center.pendingNotificationRequests().filter { request in
            guard
                isBehaviorRequest(request),
                let eventID = ReminderNotificationPayload.eventID(
                    from: request.content.userInfo
                )
            else {
                return false
            }

            return eventIDs.contains(eventID)
        }

        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier)
        )
    }

    func removeStaleBehaviorReminders(keeping eventIDs: Set<UUID>) async {
        let requests = await center.pendingNotificationRequests().filter { request in
            guard isBehaviorRequest(request) else { return false }

            guard let eventID = ReminderNotificationPayload.eventID(
                from: request.content.userInfo
            ) else {
                return true
            }

            return !eventIDs.contains(eventID)
        }

        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier)
        )
    }

    func scheduleSleepReminderIfNeeded(
        for schedule: DailySchedule,
        leadTime: TimeInterval,
        now: Date = .now
    ) async throws {
        guard var nextSleepStart = schedule.nextSleepStart(after: now) else {
            cancelSleepReminder()
            return
        }

        var reminderDate = nextSleepStart.addingTimeInterval(-leadTime)
        if reminderDate < now {
            guard let followingSleepStart = schedule.nextSleepStart(
                after: nextSleepStart
            ) else {
                cancelSleepReminder()
                return
            }

            nextSleepStart = followingSleepStart
            reminderDate = nextSleepStart.addingTimeInterval(-leadTime)
        }
        let pendingRequests = await center.pendingNotificationRequests()
        if let pendingRequest = pendingRequests.first(where: {
            $0.identifier == Identifier.sleepReminder
        }),
           let pendingSleepStart = sleepStart(from: pendingRequest.content.userInfo),
           let pendingLeadTime = sleepLeadTime(from: pendingRequest.content.userInfo),
           pendingSleepStart == nextSleepStart,
           pendingLeadTime == leadTime
        {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Wind Down"
        content.body = "Your scheduled sleep time is in \(Int(leadTime / 60)) minutes."
        content.sound = .default
        content.userInfo = [
            PayloadKey.kind: PayloadKey.sleep,
            PayloadKey.sleepLeadTime: leadTime,
            PayloadKey.sleepStart: nextSleepStart.timeIntervalSince1970
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, reminderDate.timeIntervalSince(now)),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Identifier.sleepReminder,
            content: content,
            trigger: trigger
        )

        cancelSleepReminder()
        try await center.add(request)
    }

    func cancelSleepReminder() {
        center.removePendingNotificationRequests(
            withIdentifiers: [Identifier.sleepReminder]
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard let eventID = eventID(from: notification.request.content.userInfo) else {
            completionHandler([.banner, .sound])
            return
        }

        onAction?(.delivered(eventID: eventID, at: .now))
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let eventID = eventID(from: response.notification.request.content.userInfo) else {
            if response.notification.request.identifier.hasPrefix(Identifier.testPrefix) {
                center.removeDeliveredNotifications(
                    withIdentifiers: [response.notification.request.identifier]
                )
            }
            completionHandler()
            return
        }

        let action: ReminderAction?
        switch response.actionIdentifier {
        case Category.acknowledge:
            action = .acknowledged(eventID: eventID, at: .now)
        case Category.skip, UNNotificationDismissActionIdentifier:
            action = .skipped(eventID: eventID, at: .now)
        case UNNotificationDefaultActionIdentifier:
            action = .delivered(eventID: eventID, at: .now)
        default:
            action = nil
        }

        if let action {
            switch action {
            case .acknowledged, .skipped:
                center.removeDeliveredNotifications(
                    withIdentifiers: [response.notification.request.identifier]
                )
            case .delivered:
                break
            }
            onAction?(action)
        }

        completionHandler()
    }

    private func eventID(from userInfo: [AnyHashable: Any]) -> UUID? {
        ReminderNotificationPayload.eventID(from: userInfo)
    }

    private func isBehaviorRequest(_ request: UNNotificationRequest) -> Bool {
        request.identifier.hasPrefix(Identifier.behaviorPrefix)
            && ReminderNotificationPayload.eventID(from: request.content.userInfo) != nil
    }

    private func sleepStart(from userInfo: [AnyHashable: Any]) -> Date? {
        guard
            userInfo[PayloadKey.kind] as? String == PayloadKey.sleep,
            let value = userInfo[PayloadKey.sleepStart] as? NSNumber
        else {
            return nil
        }

        return Date(timeIntervalSince1970: value.doubleValue)
    }

    private func sleepLeadTime(from userInfo: [AnyHashable: Any]) -> TimeInterval? {
        if let value = userInfo[PayloadKey.sleepLeadTime] as? NSNumber {
            return value.doubleValue
        }

        if let value = userInfo[PayloadKey.sleepLeadTime] as? TimeInterval {
            return value
        }

        return nil
    }

    private func testFireDate(from userInfo: [AnyHashable: Any]) -> Date? {
        if let value = userInfo[PayloadKey.testFireDate] as? NSNumber {
            return Date(timeIntervalSince1970: value.doubleValue)
        }

        if let value = userInfo[PayloadKey.testFireDate] as? TimeInterval {
            return Date(timeIntervalSince1970: value)
        }

        return nil
    }

    private static func behaviorIdentifier(for eventID: UUID) -> String {
        Identifier.behaviorPrefix + eventID.uuidString
    }
}
