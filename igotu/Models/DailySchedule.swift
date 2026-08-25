//
//  DailySchedule.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation

struct DailySchedule: Codable, Equatable {
    var sleepStart: DateComponents
    var sleepEnd: DateComponents
    var workStart: DateComponents
    var workEnd: DateComponents
}
