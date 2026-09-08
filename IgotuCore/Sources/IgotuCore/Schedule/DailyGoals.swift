import Foundation

public struct DailyGoals: Codable, Equatable {
    public static let hydrationRange = 1...20
    public static let standingHoursRange = 1...24

    public var hydrationCount: Int
    public var standingHours: Int

    public init(hydrationCount: Int = 8, standingHours: Int = 8) {
        self.hydrationCount = hydrationCount
        self.standingHours = standingHours
    }

    public var normalized: DailyGoals {
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
