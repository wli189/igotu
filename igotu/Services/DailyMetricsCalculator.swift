import Foundation

struct DailyMetrics: Equatable {
    let hydrationCount: Int
    let standingHours: Int
    let goals: DailyGoals
}

struct DailyMetricsCalculator {
    func calculate(
        events: [ReminderEvent],
        goals: DailyGoals,
        calendar: Calendar = .current
    ) -> DailyMetrics {
        let hydrationCount = events.filter {
            !$0.isTest && $0.behavior == .hydration
        }.count

        let standingHours = Set(
            events.compactMap { event -> Int? in
                guard !event.isTest, event.behavior == .standUp else { return nil }
                return calendar.component(
                    .hour,
                    from: event.resolvedAt ?? event.timestamp
                )
            }
        ).count

        return DailyMetrics(
            hydrationCount: hydrationCount,
            standingHours: standingHours,
            goals: goals
        )
    }
}
