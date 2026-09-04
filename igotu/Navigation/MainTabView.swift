//
//  MainTabView.swift
//  igotu
//

import SwiftUI
import Combine
import IgotuCore

struct MainTabView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum Tab: Hashable {
        case today
        case settings
    }

    @State private var selection: Tab = .today
    @State private var iPadSelection: Tab? = .today
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

        Group {
            if horizontalSizeClass == .regular {
                iPadNavigation(accent: accent)
            } else {
                phoneNavigation(accent: accent)
            }
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
            if reminderCoordinator.isShowingExpiredReminderToast {
                ExpiredReminderToastView()
                    .safeAreaPadding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let event = reminderCoordinator.toastReminders.first {
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
        .animation(
            .easeInOut(duration: 0.22),
            value: reminderCoordinator.isShowingExpiredReminderToast
        )
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

    private func phoneNavigation(accent: Color) -> some View {
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
    }

    private func iPadNavigation(accent: Color) -> some View {
        NavigationSplitView {
            List(selection: $iPadSelection) {
                Section {
                    Label("Today", systemImage: "sun.max.fill")
                        .tag(Tab.today)

                    Label("Settings", systemImage: "slider.horizontal.3")
                        .tag(Tab.settings)
                }
            }
            .navigationTitle("igotu")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            switch iPadSelection ?? .today {
            case .today:
                TodayView()
            case .settings:
                NavigationStack {
                    SetUpView(isEditing: true)
                }
                .tint(accent)
            }
        }
        .navigationSplitViewStyle(.balanced)
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
