import SwiftUI
import AppKit

enum MacTheme {
    static let accent = Color(red: 0.31, green: 0.48, blue: 0.39)
    static let blue = Color(red: 0.34, green: 0.42, blue: 0.66)
    static let warm = Color(red: 0.72, green: 0.55, blue: 0.34)
    // Keep sleep legible against macOS dark materials while preserving a quiet moonlit hue.
    static let night = Color(red: 0.48, green: 0.60, blue: 0.95)
}

struct MacAmbientBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [accent.opacity(0.10), .clear, accent.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct MacSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}
