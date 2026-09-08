import SwiftUI
import IgotuCore

struct ReminderRulesEditorView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore

    let context: ReminderContext
    var title: String?

    private var rules: [ReminderRule] {
        context == .work
            ? configuration.workReminders
            : configuration.idleReminders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let title {
                    Text(title)
                        .font(.headline)
                }

                Spacer()
                addReminderMenu
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ForEach(Array(rules.enumerated()), id: \.element.behavior) { index, rule in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, 16)
                }

                reminderRow(for: rule.behavior)
            }

            if rules.isEmpty {
                Text("No reminders added")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    private var addReminderMenu: some View {
        Menu {
            ForEach(configuration.availableReminderBehaviors(in: context)) { behavior in
                Button {
                    configuration.addReminder(for: behavior, in: context)
                } label: {
                    Label(behavior.title, systemImage: behavior.icon)
                }
            }
        } label: {
            Image(systemName: "plus")
        }
        .disabled(configuration.availableReminderBehaviors(in: context).isEmpty)
        .buttonStyle(.bordered)
    }

    private func reminderRow(for behavior: Behavior) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: behavior.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                Text(behavior.title)
                    .font(.body.weight(.semibold))

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    configuration.removeReminder(for: behavior, in: context)
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove reminder")
            }

            ReminderFrequencyEditorView(behavior: behavior, context: context)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview("Work Rules") {
    ReminderRulesEditorView(context: .work, title: "Reminder frequency")
        .environmentObject(PreviewSupport.configuration(named: "work-rules"))
        .padding()
}

#Preview("Idle Rules") {
    ReminderRulesEditorView(context: .idle, title: "Reminder frequency")
        .environmentObject(PreviewSupport.configuration(named: "idle-rules"))
        .padding()
}

#Preview("No Rules") {
    ReminderRulesEditorView(context: .work, title: "Reminder frequency")
        .environmentObject(
            PreviewSupport.configuration(
                named: "empty-rules",
                workReminders: []
            )
        )
        .padding()
}
