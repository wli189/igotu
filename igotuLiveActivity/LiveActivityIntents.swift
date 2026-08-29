import ActivityKit
import AppIntents
import UserNotifications

private func removeFallbackNotification(for eventID: UUID) {
    let identifier = WellnessReminderNotification.identifier(for: eventID)
    let center = UNUserNotificationCenter.current()

    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
}

private func finishWellnessReminder(
    eventIDString: String,
    status: LiveActivityActionStatus
) async {
    guard let eventID = UUID(uuidString: eventIDString) else {
        return
    }

    LiveActivityActionStore.record(
        eventID: eventID,
        status: status
    )
    removeFallbackNotification(for: eventID)

    let reminderState: WellnessReminderAttributes.ReminderState
    switch status {
    case .acknowledged:
        reminderState = .acknowledged
    case .skipped:
        reminderState = .skipped
    }

    await endActivity(
        eventID: eventID,
        status: reminderState
    )
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
        await finishWellnessReminder(
            eventIDString: eventID,
            status: .acknowledged
        )
        return .result()
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
        await finishWellnessReminder(
            eventIDString: eventID,
            status: .skipped
        )
        return .result()
    }
}
