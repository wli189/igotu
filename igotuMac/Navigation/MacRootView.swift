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
        NavigationSplitView {
            MacSidebar(selection: $selection)
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
        .tint(MacTheme.accent)
    }
}

private struct MacSidebar: View {
    @Binding var selection: MacSection?

    var body: some View {
        List(selection: $selection) {
            Section("IGOTU") {
                ForEach(MacSection.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("AT A GLANCE") {
                Label("A calm rhythm for your day", systemImage: "leaf.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("igotu")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Circle().fill(MacTheme.accent).frame(width: 10, height: 10)
                Text("Ambient wellness")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}

#Preview("macOS Workspace") {
    MacRootView()
        .environmentObject(MacConfigurationStore.preview())
        .environmentObject(MacReminderHistoryStore.preview())
        .frame(width: 1_120, height: 740)
}
