//
//  Untitled.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation
import Combine

final class AppConfigurationStore: ObservableObject {
    private enum Key {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let schedule = "dailySchedule"
    }

    private static let defaultSchedule = DailySchedule(
        sleepStart: DateComponents(hour: 23),
        sleepEnd: DateComponents(hour: 7),
        workStart: DateComponents(hour: 9),
        workEnd: DateComponents(hour: 18)
    )

    @Published private(set) var schedule: DailySchedule
    @Published private(set) var hasCompletedSetup: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        guard
            let data = defaults.data(forKey: Key.schedule),
            let savedSchedule = try? JSONDecoder().decode(DailySchedule.self, from: data)
        else {
            schedule = Self.defaultSchedule
            hasCompletedSetup = false
            return
        }

        schedule = savedSchedule
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
    }

    func save(schedule: DailySchedule) {
        self.schedule = schedule
        hasCompletedSetup = true

        if let data = try? JSONEncoder().encode(schedule) {
            defaults.set(data, forKey: Key.schedule)
        }

        defaults.set(true, forKey: Key.hasCompletedSetup)
    }
}
