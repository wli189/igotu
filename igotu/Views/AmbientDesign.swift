import SwiftUI

struct AmbientBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            LinearGradient(
                colors: [
                    color.opacity(0.14),
                    .clear,
                    color.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    color.opacity(0.14),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 460
            )
        }
        .animation(.easeInOut(duration: 1.2), value: color)
        .ignoresSafeArea()
    }
}

private struct AmbientSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.8),
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06),
                radius: 22,
                x: 0,
                y: 10
            )
    }
}

extension View {
    func ambientSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(AmbientSurfaceModifier(cornerRadius: cornerRadius))
    }
}
