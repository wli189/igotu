import SwiftUI
import IgotuCore

struct MacReminderToast: View {
    let event: ReminderEvent
    let onAcknowledge: () -> Void
    let onSkip: () -> Void

    var body: some View {
        MacSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: event.behavior.icon)
                        .foregroundStyle(MacTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(MacTheme.accent.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.behavior.title).font(.headline)
                        Text(event.behavior.reminderMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 12)
                }
                HStack(spacing: 10) {
                    Button(action: onAcknowledge) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacTheme.accent)
                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward.end.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(18)
        }
        .frame(width: 380)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

struct MacExpiredReminderToast: View {
    var body: some View {
        MacSurface {
            Label("This reminder has expired", systemImage: "clock.badge.exclamationmark")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
    }
}

struct MacReminderConfirmation: View {
    @EnvironmentObject private var coordinator: MacReminderCoordinator
    let event: ReminderEvent

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: event.behavior.icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(MacTheme.accent)
                .frame(width: 92, height: 92)
                .background(MacTheme.accent.opacity(0.12), in: Circle())
            VStack(spacing: 8) {
                Text("REMINDER")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MacTheme.accent)
                Text(event.behavior.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(event.behavior.reminderMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button("Skip", systemImage: "forward.end.fill") {
                    coordinator.skip(eventID: event.id)
                }
                .buttonStyle(.bordered)
                Button("Done", systemImage: "checkmark.circle.fill") {
                    coordinator.acknowledge(eventID: event.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(MacTheme.accent)
            }
        }
        .padding(40)
        .frame(width: 440, height: 360)
        .background(MacAmbientBackground(accent: MacTheme.accent))
    }
}
