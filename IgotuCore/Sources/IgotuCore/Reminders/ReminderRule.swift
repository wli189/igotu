public struct ReminderRule: Identifiable, Codable, Equatable {
    public let behavior: Behavior
    public var isEnabled: Bool
    public var frequency: ReminderFrequency

    public init(
        behavior: Behavior,
        isEnabled: Bool,
        frequency: ReminderFrequency
    ) {
        self.behavior = behavior
        self.isEnabled = isEnabled
        self.frequency = frequency
    }

    public var id: Behavior { behavior }
}
