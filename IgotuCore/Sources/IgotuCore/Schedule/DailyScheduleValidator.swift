import Foundation

public struct DailyScheduleValidator {
    public enum Issue: Equatable {
        case sleepTimesMatch
        case workTimesMatch
        case modeTimesMatch(DailyMode)
        case sleepPeriodsOverlap
        case workPeriodsOverlap
        case modePeriodsOverlap(DailyMode)
        case sleepAndWorkOverlap
        case modeOverlap(DailyMode, DailyMode)

        public var message: String {
            switch self {
            case .sleepTimesMatch:
                return "Your bedtime and wake-up time cannot be the same."
            case .workTimesMatch:
                return "Your work start time and end time cannot be the same."
            case let .modeTimesMatch(mode):
                return "Your (mode.startTitle.lowercased()) and (mode.endTitle.lowercased()) cannot be the same."
            case .sleepPeriodsOverlap:
                return "Only one sleep schedule can be set for each day."
            case .workPeriodsOverlap:
                return "Work periods cannot overlap on the same day."
            case let .modePeriodsOverlap(mode):
                return "(mode.title) periods cannot overlap on the same day."
            case .sleepAndWorkOverlap:
                return "Your work hours and bedtime overlap."
            case let .modeOverlap(first, second):
                return "Your (first.title.lowercased()) and (second.title.lowercased()) periods overlap."
            }
        }
    }

    private static let minutesPerDay = 24 * 60
    private static let minutesPerWeek = minutesPerDay * 7

    private struct AbsolutePeriod {
        let start: Int
        let end: Int
    }

    public init() {}

    public func issue(for schedule: DailySchedule) -> Issue? {
        let modes = DailyMode.scheduleModes
            .filter { !schedule.periods(for: $0).isEmpty }

        for mode in modes {
            let periods = schedule.periods(for: mode)
            if periods.contains(where: timesMatch) {
                switch mode {
                case .sleeping: return .sleepTimesMatch
                case .work: return .workTimesMatch
                case .idle: return .modeTimesMatch(mode)
                }
            }

            if mode == .sleeping,
               hasMultipleSleepSchedulesOnSameDay(periods)
            {
                return .sleepPeriodsOverlap
            }

            if hasOverlap(within: absolutePeriods(for: periods)) {
                switch mode {
                case .sleeping: return .sleepPeriodsOverlap
                case .work: return .workPeriodsOverlap
                case .idle: return .modePeriodsOverlap(mode)
                }
            }
        }

        for firstIndex in modes.indices {
            let firstMode = modes[firstIndex]
            let firstPeriods = absolutePeriods(for: schedule.periods(for: firstMode))

            for secondMode in modes.dropFirst(firstIndex + 1) {
                let secondPeriods = absolutePeriods(for: schedule.periods(for: secondMode))
                if hasOverlap(between: firstPeriods, and: secondPeriods) {
                    if Set([firstMode, secondMode]) == [.sleeping, .work] {
                        return .sleepAndWorkOverlap
                    }

                    return .modeOverlap(firstMode, secondMode)
                }
            }
        }

        return nil
    }

    private func hasMultipleSleepSchedulesOnSameDay(
        _ periods: [DailySchedulePeriod]
    ) -> Bool {
        var selectedDays = Set<Weekday>()

        for period in periods {
            if !selectedDays.isDisjoint(with: period.days) {
                return true
            }
            selectedDays.formUnion(period.days)
        }

        return false
    }

    private func timesMatch(_ period: DailySchedulePeriod) -> Bool {
        minutes(from: period.start) == minutes(from: period.end)
    }

    private func minutes(from components: DateComponents) -> Int {
        (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func absolutePeriods(
        for periods: [DailySchedulePeriod]
    ) -> [AbsolutePeriod] {
        periods.flatMap { period in
            period.days.compactMap { day in
                let dayIndex = mondayFirstIndex(of: day)
                let start = dayIndex * Self.minutesPerDay + minutes(from: period.start)
                var end = dayIndex * Self.minutesPerDay + minutes(from: period.end)

                if end <= start {
                    end += Self.minutesPerDay
                }

                return AbsolutePeriod(start: start, end: end)
            }
        }
    }

    private func hasOverlap(within periods: [AbsolutePeriod]) -> Bool {
        for firstIndex in periods.indices {
            for secondIndex in periods.indices where secondIndex > firstIndex {
                if overlapsConsideringWeekWrap(periods[firstIndex], periods[secondIndex]) {
                    return true
                }
            }
        }

        return false
    }

    private func hasOverlap(
        between firstPeriods: [AbsolutePeriod],
        and secondPeriods: [AbsolutePeriod]
    ) -> Bool {
        firstPeriods.contains { first in
            secondPeriods.contains { second in
                overlapsConsideringWeekWrap(first, second)
            }
        }
    }

    private func overlapsConsideringWeekWrap(
        _ first: AbsolutePeriod,
        _ second: AbsolutePeriod
    ) -> Bool {
        [-Self.minutesPerWeek, 0, Self.minutesPerWeek].contains { offset in
            let shiftedStart = second.start + offset
            let shiftedEnd = second.end + offset
            return first.start < shiftedEnd && first.end > shiftedStart
        }
    }

    private func mondayFirstIndex(of weekday: Weekday) -> Int {
        Weekday.mondayFirst.firstIndex(of: weekday) ?? 0
    }
}
