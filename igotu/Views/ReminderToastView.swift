import SwiftUI

struct ReminderToastView: View {
    let event: ReminderEvent
    let onAcknowledge: () -> Void
    let onSkip: () -> Void

    private let themeColorService = ThemeColorService()

    private var accent: Color {
        let theme: WellnessTheme = event.context == .work ? .work : .home
        return themeColorService.color(for: theme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: event.behavior.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.behavior.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))

                    Text(event.behavior.reminderMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text("\(event.context.title) routine")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 0)
            }

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: onAcknowledge) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(accent)

                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward.end.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .tint(accent)
                }
            }
        }
        .padding(18)
        .ambientSurface(cornerRadius: 24)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    ReminderToastView(
        event: ReminderEvent(
            behavior: .standUp,
            context: .work,
            timestamp: .now,
            status: .delivered
        ),
        onAcknowledge: {},
        onSkip: {}
    )
    .padding(.top, 100)
    .background(Color(.systemGroupedBackground))
}
