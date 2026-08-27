import Foundation
import Testing
@testable import igotu

struct WellnessThemeTests {
    @Test func dailyModesUseTheirDocumentedThemes() {
        #expect(DailyMode.work.wellnessTheme == .work)
        #expect(DailyMode.idle.wellnessTheme == .home)
        #expect(DailyMode.sleeping.wellnessTheme == .sleep)
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
