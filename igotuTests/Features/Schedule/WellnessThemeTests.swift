import Foundation
import Testing
import IgotuCore
@testable import igotu

struct WellnessThemeTests {
    @Test func dailyModesUseTheirDocumentedThemes() {
        #expect(DailyMode.work.wellnessTheme == .work)
        #expect(DailyMode.study.wellnessTheme == .study)
        #expect(DailyMode.idle.wellnessTheme == .home)
        #expect(DailyMode.sleeping.wellnessTheme == .sleep)
    }

    @Test func dailyModesExposeTheirReminderPolicies() {
        #expect(DailyMode.sleeping.reminderPolicy.allowedBehaviors.isEmpty)
        #expect(DailyMode.sleeping.reminderPolicy.defaultBehaviors.isEmpty)
        #expect(DailyMode.work.reminderPolicy.allowedBehaviors == Set(Behavior.allCases))
        #expect(DailyMode.work.reminderPolicy.defaultBehaviors == Set(Behavior.allCases))
        #expect(DailyMode.study.reminderPolicy.allowedBehaviors == [.hydration, .standUp])
        #expect(DailyMode.study.reminderPolicy.defaultBehaviors == [.hydration, .standUp])
        #expect(DailyMode.idle.reminderPolicy.allowedBehaviors == [.hydration, .movement])
        #expect(DailyMode.idle.reminderPolicy.defaultBehaviors == [.hydration, .movement])
    }

    @Test func themesRoundTripThroughCodableIdentity() throws {
        let themes = WellnessTheme.allCases
        let encoded = try JSONEncoder().encode(themes)
        let decoded = try JSONDecoder().decode([WellnessTheme].self, from: encoded)

        #expect(decoded == themes)
    }

    @Test func themesUseTheirNamedColorAssets() {
        #expect(WellnessTheme.work.colorAssetName == "ThemeWork")
        #expect(WellnessTheme.study.colorAssetName == "ThemeStudy")
        #expect(WellnessTheme.home.colorAssetName == "ThemeHome")
        #expect(WellnessTheme.sleep.colorAssetName == "ThemeSleep")
    }

}
