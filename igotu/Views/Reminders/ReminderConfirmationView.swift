import SwiftUI
import IgotuCore

struct ReminderConfirmationView: View {
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator

    let event: ReminderEvent

    private let themeColorService = ThemeColorService()

    private var accent: Color {
        let theme: WellnessTheme = event.context == .work ? .work : .home
        return themeColorService.color(for: theme)
    }

    var body: some View {
        ZStack {
            AmbientBackground(color: accent)

            ScrollView {
                VStack(spacing: 0) {
                    Text("REMINDER")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
                        Image(systemName: event.behavior.icon)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 112, height: 112)
                            .background(accent.opacity(0.13), in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(accent.opacity(0.18), lineWidth: 1)
                            }

                        Text(event.behavior.title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.top, 26)

                        Text(event.behavior.reminderMessage)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: 460)
                    .padding(.top, 70)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        Button {
                            reminderCoordinator.acknowledge(eventID: event.id)
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .tint(accent)

                        Button {
                            reminderCoordinator.skip(eventID: event.id)
                        } label: {
                            Label("Skip", systemImage: "forward.end.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .tint(accent)
                    }
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
        }
        .tint(accent)
    }
}

#Preview {
    ReminderConfirmationView(
        event: ReminderEvent(
            behavior: .hydration,
            context: .work,
            timestamp: .now,
            status: .delivered
        )
    )
    .environmentObject(AppConfigurationStore())
    .environmentObject(ReminderHistoryStore())
    .environmentObject(ReminderCoordinator(
        configuration: AppConfigurationStore(),
        engine: ReminderEngine(offsetProvider: { _ in 0 }),
        history: ReminderHistoryStore(),
        notificationScheduler: NotificationScheduler()
    ))
}
