//
//  AmbientFocusDial.swift
//  igotu
//

import SwiftUI

struct AmbientFocusDial: View {
    let progress: Double
    let icon: String
    let tint: Color

    @State private var isBreathing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: 8)

            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(tint.opacity(0.11))
                .padding(14)

            Circle()
                .fill(.ultraThinMaterial)
                .padding(17)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        .padding(17)
                }

            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 100, height: 100)
        .scaleEffect(isBreathing ? 1.02 : 1)
        .shadow(color: tint.opacity(0.16), radius: 10, x: 0, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .accessibilityHidden(true)
    }
}
