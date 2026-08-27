//
//  TodayHeaderView.swift
//  igotu
//

import SwiftUI

struct TodayHeaderView: View {
    let date: Date
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            Text("Good \(dayPeriod(for: date))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayPeriod(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return "morning"
        case 12..<18:
            return "afternoon"
        default:
            return "evening"
        }
    }
}
