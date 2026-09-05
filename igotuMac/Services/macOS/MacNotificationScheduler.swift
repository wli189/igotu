import Foundation
import UserNotifications
import IgotuCore

@MainActor
final class MacNotificationScheduler: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private enum Identifier {
        static let sleepReminder = "sleep-reminder"
        static let behaviorPrefix = "behavior-reminder."
        static let legacyNextReminder = "next-reminder"
        static let legacyBehaviorPrefix = "wellness-reminder-"
    }

    private enum PayloadKey {
        static let kind = "kind"
        static let sleep = "sleep-reminder"
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
        let category = UNNotificationCategory(
            identifier: "behavior-reminder",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
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
        let requests = await center.pendingNotificationRequests().filter {
            $0.identifier == Identifier.legacyNextReminder || $0.identifier.hasPrefix(Identifier.legacyBehaviorPrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
    }

    func schedule(event: ReminderEvent) async throws {
        let content = UNMutableNotificationContent()
        content.title = event.behavior.title
        content.subtitle = "\(event.context.title) routine"
        content.body = event.behavior.reminderMessage
        content.sound = .default
        content.categoryIdentifier = "behavior-reminder"
        content.threadIdentifier = "behavior-reminder"
        content.userInfo = ReminderNotificationPayload(eventID: event.id).userInfo

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, event.timestamp.timeIntervalSinceNow),
            repeats: false
        )
        try await center.add(UNNotificationRequest(
            identifier: Self.behaviorIdentifier(for: event.id),
            content: content,
            trigger: trigger
        ))
    }

    func removeBehaviorReminders(for eventIDs: Set<UUID>) async {
        guard !eventIDs.isEmpty else { return }
        let requests = await center.pendingNotificationRequests().filter { request in
            guard isBehaviorRequest(request), let eventID = ReminderNotificationPayload.eventID(from: request.content.userInfo) else { return false }
            return eventIDs.contains(eventID)
        }
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
    }

    func removeStaleBehaviorReminders(keeping eventIDs: Set<UUID>) async {
        let requests = await center.pendingNotificationRequests().filter { request in
            guard isBehaviorRequest(request) else { return false }
            guard let eventID = ReminderNotificationPayload.eventID(from: request.content.userInfo) else { return true }
            return !eventIDs.contains(eventID)
        }
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
    }

    func scheduleSleepReminderIfNeeded(for schedule: DailySchedule, leadTime: TimeInterval, now: Date = .now) async throws {
        guard var nextSleepStart = schedule.nextSleepStart(after: now) else {
            cancelSleepReminder()
            return
        }

        var reminderDate = nextSleepStart.addingTimeInterval(-leadTime)
        if reminderDate < now {
            guard let followingSleepStart = schedule.nextSleepStart(after: nextSleepStart) else {
                cancelSleepReminder()
                return
            }
            nextSleepStart = followingSleepStart
            reminderDate = nextSleepStart.addingTimeInterval(-leadTime)
        }

        let pendingRequests = await center.pendingNotificationRequests()
        if let pendingRequest = pendingRequests.first(where: { $0.identifier == Identifier.sleepReminder }),
           let pendingSleepStart = sleepStart(from: pendingRequest.content.userInfo),
           let pendingLeadTime = sleepLeadTime(from: pendingRequest.content.userInfo),
           pendingSleepStart == nextSleepStart, pendingLeadTime == leadTime {
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
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminderDate.timeIntervalSince(now)), repeats: false)
        cancelSleepReminder()
        try await center.add(UNNotificationRequest(identifier: Identifier.sleepReminder, content: content, trigger: trigger))
    }

    func cancelSleepReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.sleepReminder])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard let eventID = ReminderNotificationPayload.eventID(from: notification.request.content.userInfo) else {
            completionHandler([.banner, .sound])
            return
        }
        onAction?(.delivered(eventID: eventID, at: .now))
        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let eventID = ReminderNotificationPayload.eventID(from: response.notification.request.content.userInfo),
              response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
        onAction?(.opened(eventID: eventID, at: .now))
        completionHandler()
    }

    private func isBehaviorRequest(_ request: UNNotificationRequest) -> Bool {
        request.identifier.hasPrefix(Identifier.behaviorPrefix) && ReminderNotificationPayload.eventID(from: request.content.userInfo) != nil
    }

    private func sleepStart(from userInfo: [AnyHashable: Any]) -> Date? {
        guard userInfo[PayloadKey.kind] as? String == PayloadKey.sleep,
              let value = userInfo[PayloadKey.sleepStart] as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: value.doubleValue)
    }

    private func sleepLeadTime(from userInfo: [AnyHashable: Any]) -> TimeInterval? {
        (userInfo[PayloadKey.sleepLeadTime] as? NSNumber)?.doubleValue
    }

    private static func behaviorIdentifier(for eventID: UUID) -> String {
        Identifier.behaviorPrefix + eventID.uuidString
    }
}
