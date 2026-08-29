import Foundation
import UserNotifications

struct ScheduledReminder: Equatable {
    let eventID: UUID
    let candidate: ReminderCandidate

    init(eventID: UUID, candidate: ReminderCandidate) {
        self.eventID = eventID
        self.candidate = candidate
    }

    init?(request: UNNotificationRequest) {
        guard let payload = ReminderNotificationPayload(userInfo: request.content.userInfo) else {
            return nil
        }

        self.init(eventID: payload.eventID, candidate: payload.candidate)
    }
}
