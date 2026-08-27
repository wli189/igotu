import SwiftUI

enum WellnessTheme: String, Codable, Hashable, CaseIterable {
    case work
    case study
    case home
    case sleep

    var contextLabel: String {
        switch self {
        case .work: return "Work"
        case .study: return "Study"
        case .home: return "Idle"
        case .sleep: return "Wind Down"
        }
    }

    var colorAssetName: String {
        switch self {
        case .work: return "ThemeWork"
        case .study: return "ThemeStudy"
        case .home: return "ThemeHome"
        case .sleep: return "ThemeSleep"
        }
    }

    // These colors are deliberately darker than the app accents so white text remains legible
    // on a personalized Lock Screen and in the Live Activity's compact layouts.
    var activityBackground: Color {
        switch self {
        case .work:
            Color(red: 32 / 255, green: 54 / 255, blue: 42 / 255)
        case .study:
            Color(red: 44 / 255, green: 52 / 255, blue: 100 / 255)
        case .home:
            Color(red: 100 / 255, green: 70 / 255, blue: 30 / 255)
        case .sleep:
            Color(red: 29 / 255, green: 34 / 255, blue: 58 / 255)
        }
    }

    var activityAccent: Color {
        switch self {
        case .work:
            Color(red: 142 / 255, green: 191 / 255, blue: 156 / 255)
        case .study:
            Color(red: 151 / 255, green: 165 / 255, blue: 230 / 255)
        case .home:
            Color(red: 231 / 255, green: 182 / 255, blue: 105 / 255)
        case .sleep:
            Color(red: 148 / 255, green: 157 / 255, blue: 220 / 255)
        }
    }

    var activityForeground: Color {
        .white
    }

    var activitySecondaryForeground: Color {
        .white.opacity(0.76)
    }

}
