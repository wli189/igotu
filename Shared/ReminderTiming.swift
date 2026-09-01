import Foundation

enum ReminderTiming {
    static let historyRetention: TimeInterval = 30 * 24 * 60 * 60
    static let expirationGracePeriod: TimeInterval = 15 * 60
}
