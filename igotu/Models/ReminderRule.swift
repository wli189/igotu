struct ReminderRule: Identifiable, Codable {
    let behavior: Behavior
    var isEnabled: Bool
    var frequency: ReminderFrequency

    var id: Behavior { behavior }
}
