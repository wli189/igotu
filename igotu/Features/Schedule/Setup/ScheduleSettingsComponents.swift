import SwiftUI

struct ScheduleSettingsSectionLabel: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        Label(title.uppercased(), systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
    }
}

struct ScheduleSettingsSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .ambientSurface(cornerRadius: 24)
    }
}

struct ScheduleSettingsNavigationRow<Destination: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    private let destination: Destination

    init(
        title: String,
        systemImage: String,
        accent: Color,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(
                        accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
