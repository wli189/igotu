//
//  igotuApp.swift
//  igotu
//
//  Created by Brian Li on 8/17/26.
//

import SwiftUI

@main
struct igotuApp: App {
    @StateObject private var configuration = AppConfigurationStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if configuration.hasCompletedSetup {
                    TodayView()
                } else {
                    SetUpView()
                }
            }
            .environmentObject(configuration)
        }
    }
}
