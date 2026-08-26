import ActivityKit
import AppIntents
import UserNotifications

private func removeFallbackNotification(for eventID: UUID) {
    let identifier = WellnessReminderNotification.identifier(for: eventID)
    let center = UNUserNotificationCenter.current()

    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
}

struct CompleteWellnessReminderIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Wellness Reminder"
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Event ID")
    var eventID: String

    init() {
        eventID = ""
    }

    init(eventID: String) {
        self.eventID = eventID
    }

    func perform() async throws -> some IntentResult {
        guard let eventID = UUID(uuidString: eventID) else {
            return .result()
        }

        LiveActivityActionStore.record(
            eventID: eventID,
            status: .acknowledged
        )
        removeFallbackNotification(for: eventID)
        await endActivity(eventID: eventID, status: .acknowledged)
        return .result()
    }

    private func endActivity(
        eventID: UUID,
        status: WellnessReminderAttributes.ReminderState
    ) async {
        guard let activity = Activity<WellnessReminderAttributes>.activities.first(
            where: { $0.attributes.eventID == eventID }
        ) else {
            return
        }

        let state = WellnessReminderAttributes.ContentState(
            status: status,
            dueAt: activity.content.state.dueAt
        )
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .immediate
        )
    }
}

struct SkipWellnessReminderIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Wellness Reminder"
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Event ID")
    var eventID: String

    init() {
        eventID = ""
    }

    init(eventID: String) {
        self.eventID = eventID
    }

    func perform() async throws -> some IntentResult {
        guard let eventID = UUID(uuidString: eventID) else {
            return .result()
        }

        LiveActivityActionStore.record(
            eventID: eventID,
            status: .skipped
        )
        removeFallbackNotification(for: eventID)
        await endActivity(eventID: eventID)
        return .result()
    }

    private func endActivity(eventID: UUID) async {
        guard let activity = Activity<WellnessReminderAttributes>.activities.first(
            where: { $0.attributes.eventID == eventID }
        ) else {
            return
        }

        let state = WellnessReminderAttributes.ContentState(
            status: .skipped,
            dueAt: activity.content.state.dueAt
        )
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .immediate
        )
    }
}
