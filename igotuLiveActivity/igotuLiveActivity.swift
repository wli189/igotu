import ActivityKit
import SwiftUI
import WidgetKit

struct WellnessReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WellnessReminderAttributes.self) { _ in
            LiveActivityLockScreenFrame()
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityIslandSlot()
                }

                DynamicIslandExpandedRegion(.center) {
                    LiveActivityIslandSlot()
                }

                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityIslandSlot()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityIslandSlot()
                }
            } compactLeading: {
                LiveActivityIslandSlot()
            } compactTrailing: {
                LiveActivityIslandSlot()
            } minimal: {
                LiveActivityIslandSlot()
            }
        }
    }
}

private struct LiveActivityLockScreenFrame: View {
    var body: some View {
        VStack(spacing: 0) {
            LiveActivityIslandSlot()
        }
        .frame(maxWidth: .infinity, minHeight: 1)
        .accessibilityHidden(true)
    }
}

private struct LiveActivityIslandSlot: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
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
            behavior: "Placeholder",
            icon: "circle",
            message: "",
            theme: .work
        )
    }
}

extension WellnessReminderAttributes.ContentState {
    fileprivate static var preview: Self {
        Self(
            status: .pending,
            dueAt: Date.now
        )
    }
}

#Preview("Live Activity Skeleton", as: .content, using: WellnessReminderAttributes.preview) {
    WellnessReminderLiveActivity()
} contentStates: {
    WellnessReminderAttributes.ContentState.preview
}
