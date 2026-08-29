//
//  DailyModeManager.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation

struct DailyModeManager {
    private let timeline: DailyScheduleTimeline

    init(calendar: Calendar = .current) {
        timeline = DailyScheduleTimeline(calendar: calendar)
    }

    func currentInterval(
        for schedule: DailySchedule,
        at date: Date = .now
    ) -> DailyScheduleInterval {
        timeline.currentInterval(for: schedule, at: date)
    }
    
    func currentMode(
            for schedule: DailySchedule,
            at date: Date = .now
    ) -> DailyMode {
        currentInterval(for: schedule, at: date).mode
    }
}
