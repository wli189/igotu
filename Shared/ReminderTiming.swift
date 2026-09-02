import Foundation

enum ReminderTiming {
    static let historyRetention: TimeInterval = 30 * 24 * 60 * 60
    static let expirationGracePeriod: TimeInterval = 15 * 60
    static let defaultSleepReminderLeadTime: TimeInterval = 30 * 60
    static let minimumSleepReminderLeadTime: TimeInterval = 15 * 60
    static let maximumSleepReminderLeadTime: TimeInterval = 120 * 60
    static let sleepReminderLeadTimeStep: TimeInterval = 15 * 60
}
