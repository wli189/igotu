import Foundation

struct DailyScheduleValidator {
    enum Issue: Equatable {
        case sleepTimesMatch
        case workTimesMatch
        case sleepAndWorkOverlap

        var message: String {
            switch self {
            case .sleepTimesMatch:
                return "Your bedtime and wake-up time cannot be the same."
            case .workTimesMatch:
                return "Your work start time and end time cannot be the same."
            case .sleepAndWorkOverlap:
                return "Your work hours and bedtime overlap."
            }
        }
    }

    private static let minutesPerDay = 24 * 60

    func issue(for schedule: DailySchedule) -> Issue? {
        let sleepStart = minutes(from: schedule.sleepStart)
        let sleepEnd = minutes(from: schedule.sleepEnd)
        let workStart = minutes(from: schedule.workStart)
        let workEnd = minutes(from: schedule.workEnd)

        if sleepStart == sleepEnd {
            return .sleepTimesMatch
        }

        if workStart == workEnd {
            return .workTimesMatch
        }

        if overlaps(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            workStart: workStart,
            workEnd: workEnd
        ) {
            return .sleepAndWorkOverlap
        }

        return nil
    }

    private func minutes(from components: DateComponents) -> Int {
        (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func ranges(start: Int, end: Int) -> [Range<Int>] {
        guard start != end else { return [] }

        if start < end {
            return [start..<end]
        }

        return [start..<Self.minutesPerDay, 0..<end]
    }

    private func overlaps(
        sleepStart: Int,
        sleepEnd: Int,
        workStart: Int,
        workEnd: Int
    ) -> Bool {
        ranges(start: sleepStart, end: sleepEnd).contains { sleepRange in
            ranges(start: workStart, end: workEnd).contains { workRange in
                sleepRange.lowerBound < workRange.upperBound
                    && sleepRange.upperBound > workRange.lowerBound
            }
        }
    }
}
