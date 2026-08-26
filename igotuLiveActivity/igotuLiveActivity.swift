import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WellnessReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WellnessReminderAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(context.attributes.theme.activityBackground)
                .activitySystemActionForegroundColor(
                    context.attributes.theme.activityForeground
                )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivitySymbol(
                        icon: context.attributes.icon,
                        tint: context.attributes.theme.activityAccent,
                        size: 22,
                        containerSize: 44
                    )
                    .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ReminderTimeStatusView(dueAt: context.state.dueAt)
                        .foregroundStyle(context.attributes.theme.activityForeground)
                        .padding(.trailing, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityExpandedContent(context: context)
                        .padding(.horizontal, 8)
                }
            } compactLeading: {
                ActivitySymbol(
                    icon: context.attributes.icon,
                    tint: context.attributes.theme.activityAccent
                )
            } compactTrailing: {
                RemainingTimeView(dueAt: context.state.dueAt, font: .caption)
                    .frame(width: 36, alignment: .trailing)
            } minimal: {
                LiveActivityMinimalView(context: context)
            }
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<WellnessReminderAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ActivitySymbol(
                    icon: context.attributes.icon,
                    tint: context.attributes.theme.activityAccent,
                    size: 22,
                    containerSize: 44
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.theme.contextLabel.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(context.attributes.theme.activitySecondaryForeground)

                    Text(context.attributes.behavior)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(context.attributes.theme.activityForeground)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                ReminderTimeStatusView(dueAt: context.state.dueAt, font: .headline)
                    .foregroundStyle(context.attributes.theme.activityForeground)
            }

            Text(context.attributes.message)
                .font(.subheadline)
                .foregroundStyle(context.attributes.theme.activitySecondaryForeground)
                .fixedSize(horizontal: false, vertical: true)

            LiveActivityActionContent(context: context)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            context.attributes.theme.activityBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

private struct LiveActivityExpandedContent: View {
    let context: ActivityViewContext<WellnessReminderAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(context.attributes.behavior)
                .font(.headline.weight(.semibold))
                .foregroundStyle(context.attributes.theme.activityForeground)
                .lineLimit(1)

            Text(context.attributes.message)
                .font(.caption2)
                .foregroundStyle(context.attributes.theme.activitySecondaryForeground)
                .lineLimit(1)

            LiveActivityActionContent(context: context, compact: true)
        }
        .padding(.top, 4)
    }
}

private struct LiveActivityActionContent: View {
    let context: ActivityViewContext<WellnessReminderAttributes>
    var compact = false

    var body: some View {
        switch context.state.status {
        case .pending:
            HStack(spacing: compact ? 6 : 10) {
                Button(
                    intent: CompleteWellnessReminderIntent(
                        eventID: context.attributes.eventID.uuidString
                    )
                ) {
                    Label("Done", systemImage: "checkmark")
                        .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(context.attributes.theme.activityAccent)
                .accessibilityLabel(
                    "Mark " + context.attributes.behavior + " as done"
                )

                Button(
                    intent: SkipWellnessReminderIntent(
                        eventID: context.attributes.eventID.uuidString
                    )
                ) {
                    Label("Skip", systemImage: "forward.end")
                        .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(context.attributes.theme.activityAccent)
                .accessibilityLabel("Skip " + context.attributes.behavior)
            }
            .controlSize(compact ? .mini : .regular)

        case .acknowledged:
            StatusView(
                title: "Done",
                icon: "checkmark.circle.fill",
                tint: context.attributes.theme.activityAccent
            )

        case .skipped:
            StatusView(
                title: "Skipped",
                icon: "arrow.uturn.forward.circle",
                tint: context.attributes.theme.activitySecondaryForeground
            )
        }
    }
}

private struct StatusView: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .accessibilityLabel(title)
    }
}

private struct ActivitySymbol: View {
    let icon: String
    let tint: Color
    var size: CGFloat = 15
    var containerSize: CGFloat = 24

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: containerSize, height: containerSize)
            .background(tint.opacity(0.18), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct RemainingTimeView: View {
    let dueAt: Date
    var font: Font = .caption2

    var body: some View {
        Text(dueAt, style: .timer)
            .font(font.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct ReminderTimeStatusView: View {
    let dueAt: Date
    var font: Font = .subheadline

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(status(at: context.date))
                .font(font.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func status(at date: Date) -> String {
        let secondsUntilDue = dueAt.timeIntervalSince(date)

        if secondsUntilDue > 60 {
            let minutes = max(1, Int(ceil(secondsUntilDue / 60)))
            return "In \(minutes) min"
        }

        if secondsUntilDue >= -60 {
            return "Now"
        }

        return "Overdue"
    }
}

private struct LiveActivityMinimalView: View {
    let context: ActivityViewContext<WellnessReminderAttributes>

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 24, height: 24)
            .accessibilityLabel(accessibilityLabel)
    }

    private var icon: String {
        switch context.state.status {
        case .pending:
            return context.attributes.icon
        case .acknowledged:
            return "checkmark.circle.fill"
        case .skipped:
            return "arrow.uturn.forward.circle"
        }
    }

    private var tint: Color {
        context.state.status == .skipped
            ? context.attributes.theme.activitySecondaryForeground
            : context.attributes.theme.activityAccent
    }

    private var accessibilityLabel: String {
        switch context.state.status {
        case .pending:
            return context.attributes.behavior + " reminder"
        case .acknowledged:
            return "Done"
        case .skipped:
            return "Skipped"
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
            message: "Take a moment to drink some water.",
            theme: .work
        )
    }
}

extension WellnessReminderAttributes.ContentState {
    fileprivate static var preview: Self {
        Self(
            status: .pending,
            dueAt: Date.now.addingTimeInterval(4 * 60)
        )
    }

    fileprivate static var acknowledgedPreview: Self {
        Self(
            status: .acknowledged,
            dueAt: Date.now
        )
    }
}

#Preview("Live Activity", as: .content, using: WellnessReminderAttributes.preview) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.preview
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: WellnessReminderAttributes.preview) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.preview
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: WellnessReminderAttributes.preview) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.preview
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: WellnessReminderAttributes.preview) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.preview
}

#Preview("Dynamic Island Minimal Done", as: .dynamicIsland(.minimal), using: WellnessReminderAttributes.preview) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.acknowledgedPreview
}
