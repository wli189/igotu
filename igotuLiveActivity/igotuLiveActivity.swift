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
                        tint: context.attributes.theme.activityAccent
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    CountdownView(dueAt: context.state.dueAt)
                        .foregroundStyle(context.attributes.theme.activityForeground)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityExpandedContent(context: context)
                }
            } compactLeading: {
                ActivitySymbol(
                    icon: context.attributes.icon,
                    tint: context.attributes.theme.activityAccent
                )
            } compactTrailing: {
                CountdownView(dueAt: context.state.dueAt)
                    .foregroundStyle(context.attributes.theme.activityForeground)
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

                VStack(alignment: .trailing, spacing: 2) {
                    CountdownView(dueAt: context.state.dueAt, font: .title3)
                        .foregroundStyle(context.attributes.theme.activityForeground)

                    Text("until due")
                        .font(.caption2)
                        .foregroundStyle(context.attributes.theme.activitySecondaryForeground)
                }
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
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

private struct LiveActivityExpandedContent: View {
    let context: ActivityViewContext<WellnessReminderAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(context.attributes.behavior)
                .font(.headline.weight(.semibold))
                .foregroundStyle(context.attributes.theme.activityForeground)

            Text(context.attributes.message)
                .font(.caption)
                .foregroundStyle(context.attributes.theme.activitySecondaryForeground)
                .lineLimit(2)

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
            HStack(spacing: 10) {
                Button(
                    intent: CompleteWellnessReminderIntent(
                        eventID: context.attributes.eventID.uuidString
                    )
                ) {
                    Label("Done", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
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
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(context.attributes.theme.activityAccent)
                .accessibilityLabel("Skip " + context.attributes.behavior)
            }
            .controlSize(compact ? .small : .regular)

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

private struct CountdownView: View {
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

private struct LiveActivityMinimalView: View {
    let context: ActivityViewContext<WellnessReminderAttributes>

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: context.state.status == .pending
                ? context.attributes.icon
                : context.state.status == .acknowledged ? "checkmark" : "arrow.uturn.forward")
                .font(.system(size: 12, weight: .bold))

            if context.state.status == .pending {
                Text(context.state.dueAt, style: .timer)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .foregroundStyle(context.attributes.theme.activityAccent)
        .frame(width: 36, height: 30)
        .accessibilityLabel(
            context.state.status == .pending
                ? context.attributes.behavior + " reminder"
                : context.state.status == .acknowledged ? "Done" : "Skipped"
        )
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
