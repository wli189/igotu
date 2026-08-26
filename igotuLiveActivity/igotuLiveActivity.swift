import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WellnessReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WellnessReminderAttributes.self) { context in
            lockScreenView(for: context)
                .activityBackgroundTint(Color.blue.opacity(0.16))
                .activitySystemActionForegroundColor(
                    accentColor(for: context.attributes.behavior)
                )
        } dynamicIsland: { context in
            DynamicIsland {
                expandedContent(for: context)
            } compactLeading: {
                compactIcon(for: context)
            } compactTrailing: {
                compactStatus(for: context)
            } minimal: {
                compactIcon(for: context)
            }
        }
    }

    @DynamicIslandExpandedContentBuilder
    private func expandedContent(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.leading, priority: 0) {
            VStack(alignment: .leading, spacing: 8) {
                activityIcon(for: context, size: 46)

                Text(context.attributes.behavior)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 128, alignment: .leading)
        }

        DynamicIslandExpandedRegion(.trailing, priority: 10) {
            expandedTime(for: context)
        }

        DynamicIslandExpandedRegion(.bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                actionButtons(for: context, spacing: 10)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    private func lockScreenView(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                activityIcon(for: context, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.behavior)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.attributes.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                expandedStatus(for: context)
            }

            actionButtons(for: context)
        }
        .padding(16)
    }

    private func actionButtons(
        for context: ActivityViewContext<WellnessReminderAttributes>,
        spacing: CGFloat = 12
    ) -> some View {
        HStack(spacing: spacing) {
            Button(intent: CompleteWellnessReminderIntent(
                eventID: context.attributes.eventID.uuidString
            )) {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .tint(.blue)
            .buttonStyle(.borderedProminent)

            Button(intent: SkipWellnessReminderIntent(
                eventID: context.attributes.eventID.uuidString
            )) {
                Label("Skip", systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .tint(.secondary)
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private func expandedTime(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Label("Due", systemImage: "clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(context.state.dueAt, style: .time)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .multilineTextAlignment(.trailing)
        .frame(minWidth: 92, alignment: .trailing)
        .padding(.trailing, 4)
        .layoutPriority(1)
    }

    private func expandedStatus(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> some View {
        Group {
            switch context.state.status {
            case .pending:
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.dueAt, style: .time)
                        .font(.headline.monospacedDigit())
                    Text("Due")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .acknowledged:
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            case .skipped:
                Label("Skipped", systemImage: "forward.end.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.trailing)
    }

    @ViewBuilder
    private func compactStatus(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> some View {
        switch context.state.status {
        case .pending:
            Text(context.state.dueAt, style: .time)
                .monospacedDigit()
                .accessibilityLabel("Due at \(context.state.dueAt.formatted(date: .omitted, time: .shortened))")
        case .acknowledged:
            Image(systemName: "checkmark")
                .accessibilityLabel("Done")
        case .skipped:
            Image(systemName: "forward.end")
                .accessibilityLabel("Skipped")
        }
    }

    private func activityIcon(
        for context: ActivityViewContext<WellnessReminderAttributes>,
        size: CGFloat
    ) -> some View {
        Image(systemName: context.attributes.icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(accentColor(for: context.attributes.behavior))
            .frame(width: size, height: size)
    }

    private func compactIcon(
        for context: ActivityViewContext<WellnessReminderAttributes>
    ) -> some View {
        activityIcon(for: context, size: 24)
            .accessibilityLabel(context.attributes.behavior)
    }

    private func accentColor(for behavior: String) -> Color {
        switch behavior {
        case "Drink Water": return .blue
        case "Stand Up": return .green
        case "Move Around": return .orange
        default: return .blue
        }
    }

}

@main
struct igotuLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WellnessReminderLiveActivity()
    }
}

extension WellnessReminderAttributes {
    fileprivate static var preview: WellnessReminderAttributes {
        WellnessReminderAttributes(
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            behavior: "Drink Water",
            icon: "drop.fill",
            message: "Take a moment to drink some water."
        )
    }
}

extension WellnessReminderAttributes.ContentState {
    fileprivate static var pendingPreview: Self {
        Self(
            status: .pending,
            dueAt: Date.now.addingTimeInterval(15 * 60)
        )
    }

    fileprivate static var acknowledgedPreview: Self {
        Self(
            status: .acknowledged,
            dueAt: Date.now
        )
    }

    fileprivate static var skippedPreview: Self {
        Self(
            status: .skipped,
            dueAt: Date.now
        )
    }
}

#Preview("Lock Screen", as: .content, using: WellnessReminderAttributes.preview) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.pendingPreview
    WellnessReminderAttributes.ContentState.acknowledgedPreview
    WellnessReminderAttributes.ContentState.skippedPreview
}

#Preview(
    "Dynamic Island Expanded",
    as: .dynamicIsland(.expanded),
    using: WellnessReminderAttributes.preview
) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.pendingPreview
}

#Preview(
    "Dynamic Island Compact",
    as: .dynamicIsland(.compact),
    using: WellnessReminderAttributes.preview
) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.pendingPreview
}

#Preview(
    "Dynamic Island Minimal",
    as: .dynamicIsland(.minimal),
    using: WellnessReminderAttributes.preview
) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.pendingPreview
}
