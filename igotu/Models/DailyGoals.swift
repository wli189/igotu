import Foundation

struct DailyGoals: Codable, Equatable {
    static let hydrationRange = 1...20
    static let standingHoursRange = 1...24

    var hydrationCount: Int
    var standingHours: Int

    init(hydrationCount: Int = 8, standingHours: Int = 8) {
        self.hydrationCount = hydrationCount
        self.standingHours = standingHours
    }

    var normalized: DailyGoals {
        DailyGoals(
            hydrationCount: min(
                max(hydrationCount, Self.hydrationRange.lowerBound),
                Self.hydrationRange.upperBound
            ),
            standingHours: min(
                max(standingHours, Self.standingHoursRange.lowerBound),
                Self.standingHoursRange.upperBound
            )
        )
    }
}
