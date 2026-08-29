import ActivityKit
import Foundation

@MainActor
final class LiveActivityScheduler {
    private var history: ReminderHistoryStore?

    func configure(history: ReminderHistoryStore) {
        self.history = history
    }

    @discardableResult
    func synchronizeActions() -> Set<UUID> {
        let actions = LiveActivityActionStore.consume()
        var eventIDs = Set<UUID>()

        for action in actions {
            let status: ReminderEventStatus

            switch action.status {
            case .acknowledged:
                status = .acknowledged
            case .skipped:
                status = .skipped
            }

            history?.updateStatus(
                for: action.eventID,
                to: status,
                at: action.date
            )
            eventIDs.insert(action.eventID)
        }

        return eventIDs
    }

    func startIfNeeded(
        for candidate: ReminderCandidate,
        eventID: UUID,
        now: Date = .now
    ) async {
        let secondsUntilDue = candidate.dueAt.timeIntervalSince(now)
        guard
            secondsUntilDue <= ReminderTiming.liveActivityLeadTime,
            secondsUntilDue > -ReminderTiming.liveActivityGracePeriod
        else {
            await endAll()
            return
        }

        if let currentActivity,
           currentActivity.attributes.eventID == eventID,
           currentActivity.attributes.theme == candidate.mode.wellnessTheme {
            return
        }

        await endAll()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = WellnessReminderAttributes(
            eventID: eventID,
            behavior: candidate.behavior.title,
            icon: candidate.behavior.icon,
            message: candidate.behavior.reminderMessage,
            theme: candidate.mode.wellnessTheme
        )
        let state = WellnessReminderAttributes.ContentState(
            status: .pending,
            dueAt: candidate.dueAt
        )
        let content = ActivityContent(
            state: state,
            staleDate: candidate.dueAt.addingTimeInterval(
                ReminderTiming.liveActivityGracePeriod
            )
        )

        do {
            _ = try Activity<WellnessReminderAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Local notifications remain available when the system rejects an activity.
        }
    }

    func endAll() async {
        for activity in Activity<WellnessReminderAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private var currentActivity: Activity<WellnessReminderAttributes>? {
        Activity<WellnessReminderAttributes>.activities.first
    }

}
