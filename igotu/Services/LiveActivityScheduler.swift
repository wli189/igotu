import ActivityKit
import Foundation

@MainActor
final class LiveActivityScheduler {
    private let activityStaleGracePeriod: TimeInterval = 30 * 60

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
        eventID: UUID
    ) async {
        if let currentActivity,
           currentActivity.attributes.eventID == eventID {
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
            message: message(for: candidate.behavior)
        )
        let state = WellnessReminderAttributes.ContentState(
            status: .pending,
            dueAt: candidate.dueAt
        )
        let content = ActivityContent(
            state: state,
            staleDate: candidate.dueAt.addingTimeInterval(activityStaleGracePeriod)
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

    private var currentActivity: Activity<WellnessReminderAttributes>? {
        Activity<WellnessReminderAttributes>.activities.first
    }

    private func message(for behavior: Behavior) -> String {
        switch behavior {
        case .hydration:
            return "Take a moment to drink some water."
        case .standUp:
            return "Stand up and stretch for a moment."
        case .movement:
            return "Take a short walk or move around."
        }
    }
}
