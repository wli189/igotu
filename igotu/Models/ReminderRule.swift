struct ReminderRule: Identifiable, Codable, Equatable {
    let behavior: Behavior
    var isEnabled: Bool
    var frequency: ReminderFrequency

    var id: Behavior { behavior }
}
