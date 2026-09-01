//
//  igotuApp.swift
//  igotu
//
//  Created by Brian Li on 8/17/26.
//

import SwiftUI

@main
struct igotuApp: App {
    @StateObject private var configuration: AppConfigurationStore

    private let history: ReminderHistoryStore

    init() {
        let configuration = AppConfigurationStore()
        let history = ReminderHistoryStore()

        _configuration = StateObject(wrappedValue: configuration)
        self.history = history
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if configuration.hasCompletedSetup {
                    MainTabView()
                } else {
                    NavigationStack {
                        SetUpView()
                    }
                }
            }
            .environmentObject(configuration)
            .environmentObject(history)
        }
    }
}
