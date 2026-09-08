import Foundation

public enum ReminderTiming {
    public static let historyRetention: TimeInterval = 30 * 24 * 60 * 60
    public static let expirationGracePeriod: TimeInterval = 15 * 60
    public static let expiredToastPresentationDuration: TimeInterval = 3
    public static let notificationPlanningHorizon: TimeInterval = 12 * 60 * 60
    public static let maximumPendingBehaviorNotifications = 60
    public static let backgroundRefreshEarliestInterval: TimeInterval = 30 * 60
    public static let compensationDelay: TimeInterval = 9 * 60
    public static let testNotificationDelay: TimeInterval = 5
    public static let testRepeatDelay: TimeInterval = 5
    public static let testExpirationGracePeriod: TimeInterval = 10
    public static let defaultSleepReminderLeadTime: TimeInterval = 30 * 60
    public static let minimumSleepReminderLeadTime: TimeInterval = 15 * 60
    public static let maximumSleepReminderLeadTime: TimeInterval = 120 * 60
    public static let sleepReminderLeadTimeStep: TimeInterval = 15 * 60
}
