import SwiftUI

enum WellnessTheme: String, Codable, Hashable, CaseIterable {
    case work
    case study
    case home
    case sleep

    var accent: Color {
        let components = accentComponents
        return Color(
            red: components.red,
            green: components.green,
            blue: components.blue
        )
    }

    var accentComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .work:
            (red: 94 / 255, green: 133 / 255, blue: 112 / 255)
        case .study:
            (red: 107 / 255, green: 124 / 255, blue: 181 / 255)
        case .home:
            (red: 194 / 255, green: 155 / 255, blue: 98 / 255)
        case .sleep:
            (red: 58 / 255, green: 64 / 255, blue: 90 / 255)
        }
    }

}
