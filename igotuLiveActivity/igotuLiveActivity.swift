import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WellnessReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WellnessReminderAttributes.self) { context in
            lockScreenView(for: context)
                .activityBackgroundTint(Color.blue.opacity(0.16))
                .activitySystemActionForegroundColor(.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.behavior, systemImage: context.attributes.icon)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.dueAt, style: .timer)
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    actionButtons(for: context)
                }
            } compactLeading: {
                Image(systemName: context.attributes.icon)
            } compactTrailing: {
                Text(context.state.dueAt, style: .timer)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.attributes.icon)
            }
        }
    }

    private func lockScreenView(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: context.attributes.icon)
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.behavior)
                        .font(.headline)
                    Text(context.attributes.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(context.state.dueAt, style: .timer)
                    .font(.headline.monospacedDigit())
            }

            actionButtons(for: context)
        }
        .padding()
    }

    private func actionButtons(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> some View {
        HStack(spacing: 8) {
            Button(intent: CompleteWellnessReminderIntent(
                eventID: context.attributes.eventID.uuidString
            )) {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .tint(.blue)

            Button(intent: SkipWellnessReminderIntent(
                eventID: context.attributes.eventID.uuidString
            )) {
                Label("Skip", systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .tint(.gray)
        }
        .buttonStyle(.borderedProminent)
    }
}

@main
struct igotuLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WellnessReminderLiveActivity()
    }
}
