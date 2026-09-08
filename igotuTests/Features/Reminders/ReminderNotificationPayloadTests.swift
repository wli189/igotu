import Foundation
import Testing
import IgotuCore
@testable import igotu

struct ReminderNotificationPayloadTests {
    @Test func payloadRoundTripsEventID() {
        let eventID = UUID()
        let payload = ReminderNotificationPayload(eventID: eventID)

        #expect(ReminderNotificationPayload(userInfo: payload.userInfo)?.eventID == eventID)
    }

    @Test func payloadRejectsUnknownVersion() {
        var userInfo = ReminderNotificationPayload(eventID: UUID()).userInfo
        userInfo["version"] = 2

        #expect(ReminderNotificationPayload(userInfo: userInfo) == nil)
    }

    @Test func payloadRejectsSleepNotification() {
        let userInfo: [AnyHashable: Any] = [
            "kind": "sleep-reminder",
            "sleepStart": Date.now.timeIntervalSince1970
        ]

        #expect(ReminderNotificationPayload(userInfo: userInfo) == nil)
    }
}
