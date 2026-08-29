import Foundation
import Testing
import UserNotifications
@testable import igotu

struct ReminderNotificationPayloadTests {
    @Test func payloadPreservesEventAndDueDate() {
        let eventID = UUID()
        let candidate = ReminderCandidate(
            behavior: .hydration,
            mode: .work,
            dueAt: Date(timeIntervalSince1970: 1_000_123.5)
        )
        let payload = ReminderNotificationPayload(eventID: eventID, candidate: candidate)

        let content = UNMutableNotificationContent()
        content.userInfo = payload.userInfo
        let request = UNNotificationRequest(
            identifier: "wellness-reminder-\(eventID.uuidString)",
            content: content,
            trigger: nil
        )
        let restored = ScheduledReminder(request: request)

        #expect(restored?.eventID == eventID)
        #expect(restored?.candidate == candidate)
    }
}
