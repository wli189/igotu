import Foundation
import Combine

final class ReminderHistoryStore: ObservableObject {
    private enum Key {
        static let events = "reminderEvents"
    }

    private let defaults: UserDefaults
    private let retention = ReminderTiming.historyRetention

    @Published private(set) var events: [ReminderEvent]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        events = Self.loadPersistedEvents(from: defaults)
    }

    func recentEvents(
        since date: Date,
        now: Date = .now
    ) -> [ReminderEvent] {
        currentEvents(now: now).filter {
            guard
                $0.timestamp >= date,
                $0.status.countsTowardCooldown,
                let anchor = $0.cooldownAnchor(
                    expirationGracePeriod: ReminderTiming.expirationGracePeriod
                )
            else {
                return false
            }

            return anchor <= now
        }
    }

    func status(for eventID: UUID) -> ReminderEventStatus? {
        events.first { $0.id == eventID }?.status
    }

    func recordScheduled(
        behavior: Behavior,
        context: ReminderContext,
        dueAt: Date,
        now: Date = .now
    ) -> ReminderEvent {
        let event = ReminderEvent(
            behavior: behavior,
            context: context,
            timestamp: dueAt,
            status: .scheduled
        )
        append(event, now: now)
        return event
    }

    func updateStatus(
        for eventID: UUID,
        to status: ReminderEventStatus,
        at date: Date = .now
    ) {
        var events = currentEvents(now: date)
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            return
        }

        guard !events[index].status.isTerminal else {
            return
        }

        guard events[index].status != status else {
            return
        }

        events[index].status = status
        events[index].resolvedAt = date
        persist(events, now: date)
    }

    func expireScheduledEvents(
        before date: Date = .now,
        gracePeriod: TimeInterval = 0
    ) {
        var events = currentEvents(now: date)
        var didChange = false

        for index in events.indices where
            events[index].status == .scheduled || events[index].status == .delivered
        {
            let expirationDate = events[index].timestamp.addingTimeInterval(gracePeriod)
            guard expirationDate <= date else { continue }

            events[index].status = .expired
            events[index].resolvedAt = date
            didChange = true
        }

        if didChange {
            persist(events, now: date)
        }
    }

    func cancelScheduledEvents(
        for behavior: Behavior? = nil,
        in context: ReminderContext? = nil,
        at date: Date = .now
    ) {
        var events = currentEvents(now: date)
        var didChange = false

        for index in events.indices where events[index].status == .scheduled {
            let matchesBehavior = behavior == nil || events[index].behavior == behavior
            let matchesContext = context == nil || events[index].context == context

            guard matchesBehavior && matchesContext else { continue }

            events[index].status = .cancelled
            events[index].resolvedAt = date
            didChange = true
        }

        if didChange {
            persist(events, now: date)
        }
    }

    func completedEvents(
        on day: Date = .now,
        calendar: Calendar = .current
    ) -> [ReminderEvent] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }

        return currentEvents(now: day).filter {
            guard $0.status.countsTowardCompletion else { return false }
            let completionDate = $0.resolvedAt ?? $0.timestamp
            return completionDate >= start && completionDate < end
        }
    }

    private func append(_ event: ReminderEvent, now: Date = .now) {
        var events = currentEvents(now: now)
        events.append(event)
        persist(events, now: now)
    }

    private func currentEvents(now: Date) -> [ReminderEvent] {
        let cutoff = now.addingTimeInterval(-retention)
        return events.filter { $0.timestamp >= cutoff }
    }

    private static func loadPersistedEvents(from defaults: UserDefaults) -> [ReminderEvent] {
        guard
            let data = defaults.data(forKey: Key.events),
            let events = try? JSONDecoder().decode([ReminderEvent].self, from: data)
        else {
            return []
        }

        return events
    }

    private func persist(_ events: [ReminderEvent], now: Date) {
        let cutoff = now.addingTimeInterval(-retention)
        let retainedEvents = events.filter { $0.timestamp >= cutoff }
        self.events = retainedEvents

        guard let data = try? JSONEncoder().encode(retainedEvents) else {
            return
        }

        defaults.set(data, forKey: Key.events)
    }
}
