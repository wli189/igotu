//
//  ReminderFrequency.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import Foundation

public struct ReminderFrequency: Codable, Equatable, Hashable, Identifiable {
    public enum Preset: String, Codable {
        case occasional
        case regular
        case frequent
    }

    private enum CodingKeys: String, CodingKey {
        case preset
        case interval
        case offsetLowerBound
        case offsetUpperBound
    }

    public let preset: Preset?
    public let interval: TimeInterval
    public let offsetRange: ClosedRange<TimeInterval>

    public var id: String {
        if let preset {
            return preset.rawValue
        }

        return "custom-\(interval)-\(offsetRange.lowerBound)-\(offsetRange.upperBound)"
    }

    public var isCustom: Bool { preset == nil }

    public struct PresetOption: Identifiable, Equatable, Hashable {
        public let frequency: ReminderFrequency

        public var id: String { frequency.id }
        public var title: String { frequency.title }

        public init(frequency: ReminderFrequency) {
            self.frequency = frequency
        }
    }

    public var customValue: ReminderFrequency {
        ReminderFrequency(interval: interval, offsetRange: offsetRange)
    }

    public static func maximumOffsetMinutes(for interval: TimeInterval) -> Int {
        max(1, Int((interval / 60 / 5).rounded(.down)))
    }

    public static let standardIntervals: [TimeInterval] = [
        15, 30, 45, 60, 120, 180, 240, 300, 360
    ].map { $0 * 60 }

    public static func intervalOptions(including interval: TimeInterval) -> [TimeInterval] {
        Array(Set(availableIntervals + [interval])).sorted()
    }

    /// The interval catalog used by editors. Add future choices here instead
    /// of duplicating interval values in individual views.
    public static var availableIntervals: [TimeInterval] {
        standardIntervals
    }

    public static func offsetTierMinutes(for interval: TimeInterval) -> [Int] {
        let maximum = maximumOffsetMinutes(for: interval)
        return Array(Set([
            0,
            Int((Double(maximum) / 3).rounded()),
            Int((Double(maximum) * 2 / 3).rounded()),
            maximum
        ])).sorted()
    }

    public static func nearestOffsetMinutes(to minutes: Double, for interval: TimeInterval) -> Double {
        offsetTierMinutes(for: interval).map(Double.init).min {
            let leftDistance = abs($0 - minutes)
            let rightDistance = abs($1 - minutes)
            return leftDistance == rightDistance ? $0 < $1 : leftDistance < rightDistance
        } ?? 0
    }

    public var title: String {
        switch preset {
        case .occasional: return "Occasional"
        case .regular: return "Regular"
        case .frequent: return "Frequent"
        case nil: return "Custom"
        }
    }

    public static let occasional = ReminderFrequency(
        preset: .occasional,
        interval: 2 * 60 * 60,
        offsetRange: -12 * 60 ... 12 * 60
    )

    public static let regular = ReminderFrequency(
        preset: .regular,
        interval: 60 * 60,
        offsetRange: -7 * 60 ... 7 * 60
    )

    public static let frequent = ReminderFrequency(
        preset: .frequent,
        interval: 30 * 60,
        offsetRange: -3 * 60 ... 3 * 60
    )

    public static let allCases = [occasional, regular, frequent]

    public static var presetOptions: [PresetOption] {
        allCases.map(PresetOption.init(frequency:))
    }

    public init(interval: TimeInterval, offsetRange: ClosedRange<TimeInterval>) {
        self.init(
            preset: nil,
            interval: interval,
            offsetRange: offsetRange
        )
    }

    private init(
        preset: Preset?,
        interval: TimeInterval,
        offsetRange: ClosedRange<TimeInterval>
    ) {
        self.preset = preset
        self.interval = max(interval, 1)

        let lowerBound = min(offsetRange.lowerBound, offsetRange.upperBound)
        let upperBound = max(offsetRange.lowerBound, offsetRange.upperBound)
        self.offsetRange = lowerBound ... upperBound
    }

    public init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()

        // Rules saved before custom frequencies were introduced encoded the
        // preset as a single string (for example, "regular").
        if let rawValue = try? singleValue.decode(String.self),
           let preset = Preset(rawValue: rawValue)
        {
            self = Self(for: preset)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preset = try container.decodeIfPresent(Preset.self, forKey: .preset)
        let interval = try container.decode(TimeInterval.self, forKey: .interval)
        let lowerBound = try container.decode(
            TimeInterval.self,
            forKey: .offsetLowerBound
        )
        let upperBound = try container.decode(
            TimeInterval.self,
            forKey: .offsetUpperBound
        )

        guard interval.isFinite,
              lowerBound.isFinite,
              upperBound.isFinite
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .interval,
                in: container,
                debugDescription: "Frequency values must be finite."
            )
        }

        self.init(
            preset: preset,
            interval: interval,
            offsetRange: lowerBound ... upperBound
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(preset, forKey: .preset)
        try container.encode(interval, forKey: .interval)
        try container.encode(offsetRange.lowerBound, forKey: .offsetLowerBound)
        try container.encode(offsetRange.upperBound, forKey: .offsetUpperBound)
    }

    private init(for preset: Preset) {
        switch preset {
        case .occasional:
            self = .occasional
        case .regular:
            self = .regular
        case .frequent:
            self = .frequent
        }
    }
}
