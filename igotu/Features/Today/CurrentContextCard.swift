//
//  CurrentContextCard.swift
//  igotu
//

import SwiftUI
import IgotuCore

struct CurrentContextCard: View {
    let mode: DailyMode
    let progress: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CURRENT CONTEXT")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            HStack(alignment: .center, spacing: 18) {
                AmbientFocusDial(
                    progress: progress,
                    icon: mode.icon,
                    tint: accent
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text(mode.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(mode.nudgeTitle)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ambientSurface(cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current context: \(mode.title). \(mode.nudgeTitle)")
    }

}
