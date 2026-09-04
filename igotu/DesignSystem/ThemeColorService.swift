import Foundation
import SwiftUI
import IgotuCore

struct ThemeColorService {
    private let modeManager: DailyModeManager

    init(modeManager: DailyModeManager = DailyModeManager()) {
        self.modeManager = modeManager
    }

    func currentMode(for schedule: DailySchedule, at date: Date = .now) -> DailyMode {
        modeManager.currentMode(for: schedule, at: date)
    }

    func currentTheme(for schedule: DailySchedule, at date: Date = .now) -> WellnessTheme {
        theme(for: currentMode(for: schedule, at: date))
    }

    func theme(for mode: DailyMode) -> WellnessTheme {
        mode.wellnessTheme
    }

    func color(for theme: WellnessTheme) -> Color {
        Color(theme.colorAssetName)
    }

    func currentColor(for schedule: DailySchedule, at date: Date = .now) -> Color {
        color(for: currentTheme(for: schedule, at: date))
    }
}
