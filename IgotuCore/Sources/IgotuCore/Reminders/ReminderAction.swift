import Foundation

public enum ReminderAction: Equatable {
    case delivered(eventID: UUID, at: Date)
    case opened(eventID: UUID, at: Date)
    case acknowledged(eventID: UUID, at: Date)
    case skipped(eventID: UUID, at: Date)
}
