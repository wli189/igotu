import Foundation

enum ReminderTiming {
    static let historyRetention: TimeInterval = 30 * 24 * 60 * 60
    static let sleepReminderLeadTime: TimeInterval = 30 * 60
    static let liveActivityLeadTime: TimeInterval = 5 * 60
    static let liveActivityGracePeriod: TimeInterval = 15 * 60
}
