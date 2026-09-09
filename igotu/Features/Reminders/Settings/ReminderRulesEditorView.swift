import SwiftUI
import IgotuCore

struct ReminderRulesEditorView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore

    let context: ReminderContext
    let accent: Color
    var title: String?
    var headerSystemImage: String? = nil
    var horizontalPadding: CGFloat = 16

    private var rules: [ReminderRule] {
        context == .work
            ? configuration.workReminders
            : configuration.idleReminders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let title {
                    if let headerSystemImage {
                        Label(title, systemImage: headerSystemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                    } else {
                        Text(title)
                            .font(.headline)
                    }
                }

                Spacer()
                if canAddReminder {
                    addReminderMenu
                }
            }
            .frame(minHeight: 40)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 16)

            ForEach(Array(rules.enumerated()), id: \.element.behavior) { index, rule in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, horizontalPadding)
                }

                reminderRow(for: rule.behavior)
            }

            if rules.isEmpty {
                Text("No reminders added")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 16)
            }
        }
    }

    private var canAddReminder: Bool {
        !configuration.availableReminderBehaviors(in: context).isEmpty
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
            CircularAddButtonLabel(accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add reminder")
    }

    private func reminderRow(for behavior: Behavior) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: behavior.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.12), in: Circle())

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
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 14)
    }
}

#Preview("Work Rules") {
    ReminderRulesEditorView(
        context: .work,
        accent: .blue,
        title: "Reminder frequency"
    )
        .environmentObject(PreviewSupport.configuration(named: "work-rules"))
        .padding()
}

#Preview("Idle Rules") {
    ReminderRulesEditorView(
        context: .idle,
        accent: .orange,
        title: "Reminder frequency"
    )
        .environmentObject(PreviewSupport.configuration(named: "idle-rules"))
        .padding()
}

#Preview("No Rules") {
    ReminderRulesEditorView(
        context: .work,
        accent: .blue,
        title: "Reminder frequency"
    )
        .environmentObject(
            PreviewSupport.configuration(
                named: "empty-rules",
                workReminders: []
            )
        )
        .padding()
}
