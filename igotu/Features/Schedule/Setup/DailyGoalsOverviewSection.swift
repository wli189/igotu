import SwiftUI

struct DailyGoalsOverviewSection: View {
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScheduleSettingsSectionLabel(
                title: "Daily goals",
                systemImage: "target",
                accent: accent
            )

            ScheduleSettingsSurface {
                ScheduleSettingsNavigationRow(
                    title: "Water and standing",
                    systemImage: "target",
                    accent: accent
                ) {
                    DailyGoalsSettingsView()
                }
            }
        }
    }
}
