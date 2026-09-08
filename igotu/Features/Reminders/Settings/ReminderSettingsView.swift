import SwiftUI
import IgotuCore

struct ReminderSettingsView: View {
    let context: ReminderContext
    private let themeColorService = ThemeColorService()

    @EnvironmentObject private var configuration: AppConfigurationStore

    var body: some View {
        let accent = themeColorService.currentColor(for: configuration.schedule)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Reminders", systemImage: "bell.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)

                ReminderRulesEditorView(context: context)
                    .ambientSurface(cornerRadius: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background {
            AmbientBackground(color: accent)
        }
        .tint(accent)
        .navigationTitle(context.title)
    }
}

#Preview("Work") {
    NavigationStack {
        ReminderSettingsView(context: .work)
            .environmentObject(PreviewSupport.configuration(named: "work-settings"))
    }
}

#Preview("Idle") {
    NavigationStack {
        ReminderSettingsView(context: .idle)
            .environmentObject(PreviewSupport.configuration(named: "idle-settings"))
    }
}
