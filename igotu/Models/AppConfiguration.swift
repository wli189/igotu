//
//  AppConfiguration.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

struct AppConfiguration {
    var schedule: DailySchedule
    var workReminders: [Behavior: ReminderFrequency]
    var idleReminders: [Behavior: ReminderFrequency]
}
