//
//  DailySchedule.swift
//  igotu
//

import Foundation

public struct DailySchedulePeriod: Codable, Equatable, Identifiable {
    public let id: UUID
    public var start: DateComponents
    public var end: DateComponents
    public var days: Set<Weekday>

    public init(
        id: UUID = UUID(),
        start: DateComponents,
        end: DateComponents,
        days: Set<Weekday>
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.days = days
    }
}

public struct DailySchedule: Codable, Equatable {
    public private(set) var periodsByMode: [DailyMode: [DailySchedulePeriod]]

    public var scheduledModes: [DailyMode] {
        DailyMode.scheduleModes.filter { periodsByMode[$0]?.isEmpty == false }
    }

    public init(periodsByMode: [DailyMode: [DailySchedulePeriod]]) {
        self.periodsByMode = periodsByMode.filter { mode, periods in
            mode.isSchedulable && !periods.isEmpty
        }
    }

    public init(
        sleepPeriods: [DailySchedulePeriod],
        workPeriods: [DailySchedulePeriod]
    ) {
        self.init(periodsByMode: [
            .sleeping: sleepPeriods,
            .work: workPeriods
        ])
    }

    // This initializer keeps callers and saved data from the first version compatible.
    public init(
        sleepStart: DateComponents,
        sleepEnd: DateComponents,
        workStart: DateComponents,
        workEnd: DateComponents,
        workdays: Set<Weekday> = Weekday.defaultWorkdays
    ) {
        self.init(
            sleepPeriods: [DailySchedulePeriod(
                start: sleepStart,
                end: sleepEnd,
                days: Set(Weekday.allCases)
            )],
            workPeriods: [DailySchedulePeriod(
                start: workStart,
                end: workEnd,
                days: workdays
            )]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case periodsByMode
        case sleepPeriods
        case workPeriods
        case sleepStart
        case sleepEnd
        case workStart
        case workEnd
        case workdays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let savedPeriodsByMode = try container.decodeIfPresent(
            [DailyMode: [DailySchedulePeriod]].self,
            forKey: .periodsByMode
        ) {
            self.init(periodsByMode: savedPeriodsByMode)
            return
        }

        if let savedSleepPeriods = try container.decodeIfPresent(
            [DailySchedulePeriod].self,
            forKey: .sleepPeriods
        ), let savedWorkPeriods = try container.decodeIfPresent(
            [DailySchedulePeriod].self,
            forKey: .workPeriods
        ) {
            self.init(
                sleepPeriods: savedSleepPeriods,
                workPeriods: savedWorkPeriods
            )
            return
        }

        let sleepStart = try container.decode(DateComponents.self, forKey: .sleepStart)
        let sleepEnd = try container.decode(DateComponents.self, forKey: .sleepEnd)
        let workStart = try container.decode(DateComponents.self, forKey: .workStart)
        let workEnd = try container.decode(DateComponents.self, forKey: .workEnd)
        let workdays = try container.decodeIfPresent(Set<Weekday>.self, forKey: .workdays)
            ?? Weekday.defaultWorkdays

        self.init(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            workStart: workStart,
            workEnd: workEnd,
            workdays: workdays
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(periodsByMode, forKey: .periodsByMode)
        // Keep sleep/work keys for older app versions that only understand
        // the original two-mode schedule shape.
        try container.encode(sleepPeriods, forKey: .sleepPeriods)
        try container.encode(workPeriods, forKey: .workPeriods)
    }
}

extension DailySchedule {
    public func periods(for mode: DailyMode) -> [DailySchedulePeriod] {
        periodsByMode[mode] ?? []
    }

    public mutating func setPeriods(
        _ periods: [DailySchedulePeriod],
        for mode: DailyMode
    ) {
        guard mode.isSchedulable else { return }

        if periods.isEmpty {
            periodsByMode.removeValue(forKey: mode)
        } else {
            periodsByMode[mode] = periods
        }
    }

    public var sleepPeriods: [DailySchedulePeriod] {
        get { periods(for: .sleeping) }
        set { setPeriods(newValue, for: .sleeping) }
    }

    public var workPeriods: [DailySchedulePeriod] {
        get { periods(for: .work) }
        set { setPeriods(newValue, for: .work) }
    }

    // Legacy accessors remain useful to older callers while the UI moves to period lists.
    public var sleepStart: DateComponents {
        sleepPeriods.first?.start ?? DateComponents(hour: 23)
    }

    public var sleepEnd: DateComponents {
        sleepPeriods.first?.end ?? DateComponents(hour: 7)
    }

    public var workStart: DateComponents {
        workPeriods.first?.start ?? DateComponents(hour: 9)
    }

    public var workEnd: DateComponents {
        workPeriods.first?.end ?? DateComponents(hour: 18)
    }

    public var workdays: Set<Weekday> {
        Set(workPeriods.flatMap(\.days))
    }

    public func periods(for mode: DailyMode, on date: Date, calendar: Calendar = .current)
        -> [DailySchedulePeriod]
    {
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: date))
        let periods = periods(for: mode)

        return periods
            .filter { period in
                weekday.map { period.days.contains($0) } ?? false
            }
            .sorted { first, second in
                let firstKey = periodSortKey(first)
                let secondKey = periodSortKey(second)
                if firstKey.hour != secondKey.hour {
                    return firstKey.hour < secondKey.hour
                }
                if firstKey.minute != secondKey.minute {
                    return firstKey.minute < secondKey.minute
                }
                return firstKey.id.uuidString < secondKey.id.uuidString
            }
    }

    public func nextSleepStart(
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard !sleepPeriods.isEmpty else { return nil }

        let startOfToday = calendar.startOfDay(for: date)

        for dayOffset in 0...8 {
            guard let anchor = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: startOfToday
            ) else {
                continue
            }

            let weekday = Weekday(rawValue: calendar.component(.weekday, from: anchor))
            let candidates = sleepPeriods.compactMap { period -> Date? in
                guard let weekday, period.days.contains(weekday) else { return nil }
                return dateAt(period.start, on: anchor, calendar: calendar)
            }

            if let next = candidates.filter({ $0 > date }).min() {
                return next
            }
        }

        return nil
    }

    private func periodSortKey(_ period: DailySchedulePeriod) -> (
        hour: Int,
        minute: Int,
        id: UUID
    ) {
        (
            period.start.hour ?? 0,
            period.start.minute ?? 0,
            period.id
        )
    }

    private func dateAt(
        _ components: DateComponents,
        on date: Date,
        calendar: Calendar
    ) -> Date? {
        calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: date
        )
    }
}
