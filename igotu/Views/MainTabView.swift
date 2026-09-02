//
//  MainTabView.swift
//  igotu
//

import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator

    private enum Tab: Hashable {
        case today
        case settings
    }

    @State private var selection: Tab = .today
    @State private var activeTheme: WellnessTheme?
    private let themeColorService = ThemeColorService()
    private let themeRefreshTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        let theme = activeTheme ?? themeColorService.currentTheme(for: configuration.schedule)
        let accent = themeColorService.color(for: theme)

        TabView(selection: $selection) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            NavigationStack {
                SetUpView(isEditing: true)
            }
            .tint(accent)
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
            .tag(Tab.settings)
        }
        .tint(accent)
        .onAppear {
            refreshTheme()
        }
        .onReceive(themeRefreshTimer) { _ in
            refreshTheme()
        }
        .onChange(of: configuration.schedule) { _, _ in
            refreshTheme()
        }
        .overlay(alignment: .top) {
            if let event = reminderCoordinator.toastReminders.first {
                ReminderToastView(
                    event: event,
                    onAcknowledge: {
                        reminderCoordinator.acknowledge(eventID: event.id)
                    },
                    onSkip: {
                        reminderCoordinator.skip(eventID: event.id)
                    }
                )
                .safeAreaPadding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { reminderCoordinator.fullScreenReminder != nil },
                set: { isPresented in
                    if !isPresented {
                        reminderCoordinator.dismissFullScreenReminder()
                    }
                }
            )
        ) {
            if let event = reminderCoordinator.fullScreenReminder {
                ReminderConfirmationView(event: event)
                    .environmentObject(reminderCoordinator)
            } else {
                Color.clear
            }
        }
    }

    private func refreshTheme() {
        let theme = themeColorService.currentTheme(for: configuration.schedule)
        guard activeTheme != theme else { return }

        activeTheme = theme
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppConfigurationStore())
        .environmentObject(ReminderHistoryStore())
        .environmentObject(ReminderCoordinator(
            configuration: AppConfigurationStore(),
            engine: ReminderEngine(offsetProvider: { _ in 0 }),
            history: ReminderHistoryStore(),
            notificationScheduler: NotificationScheduler()
        ))
}
