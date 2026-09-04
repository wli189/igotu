enum WellnessTheme: String, Codable, Hashable, CaseIterable {
    case work
    case study
    case home
    case sleep

    var colorAssetName: String {
        switch self {
        case .work: return "ThemeWork"
        case .study: return "ThemeStudy"
        case .home: return "ThemeHome"
        case .sleep: return "ThemeSleep"
        }
    }

}
