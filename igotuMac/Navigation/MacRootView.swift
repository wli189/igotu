import SwiftUI
import IgotuCore

enum MacSection: String, CaseIterable, Hashable, Identifiable {
    case today
    case schedule
    case reminders

    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: return "Today"
        case .schedule: return "Schedule"
        case .reminders: return "Reminders"
        }
    }
    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .schedule: return "calendar"
        case .reminders: return "bell.fill"
        }
    }
}

struct MacRootView: View {
    @EnvironmentObject private var configuration: MacConfigurationStore
    @State private var selection: MacSection? = .today

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let accent = MacTheme.currentColor(for: configuration.schedule, at: timeline.date)

            NavigationSplitView {
                MacSidebar(selection: $selection, accent: accent)
            } detail: {
                Group {
                    switch selection ?? .today {
                    case .today: MacTodayView()
                    case .schedule: MacScheduleView()
                    case .reminders: MacRemindersView()
                    }
                }
                .id(selection ?? .today)
                .environmentObject(configuration)
            }
            .navigationSplitViewStyle(.balanced)
            .tint(accent)
            .environment(\.macAccent, accent)
        }
    }
}

private struct MacSidebar: View {
    @Binding var selection: MacSection?
    let accent: Color

    var body: some View {
        List(selection: $selection) {
            Section("IGOTU") {
                ForEach(MacSection.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("igotu")
    }
}

#Preview("macOS Workspace") {
    MacRootView()
        .environmentObject(MacConfigurationStore.preview())
        .environmentObject(MacReminderHistoryStore.preview())
        .frame(width: 1_120, height: 740)
}
