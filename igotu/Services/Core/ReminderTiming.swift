import Foundation

enum ReminderTiming {
    static let historyRetention: TimeInterval = 30 * 24 * 60 * 60
    static let expirationGracePeriod: TimeInterval = 15 * 60
    static let expiredToastPresentationDuration: TimeInterval = 3
    static let notificationPlanningHorizon: TimeInterval = 12 * 60 * 60
    static let maximumPendingBehaviorNotifications = 60
    static let backgroundRefreshEarliestInterval: TimeInterval = 30 * 60
    static let compensationDelay: TimeInterval = 9 * 60
    static let testNotificationDelay: TimeInterval = 5
    static let testRepeatDelay: TimeInterval = 5
    static let testExpirationGracePeriod: TimeInterval = 10
    static let defaultSleepReminderLeadTime: TimeInterval = 30 * 60
    static let minimumSleepReminderLeadTime: TimeInterval = 15 * 60
    static let maximumSleepReminderLeadTime: TimeInterval = 120 * 60
    static let sleepReminderLeadTimeStep: TimeInterval = 15 * 60
}
