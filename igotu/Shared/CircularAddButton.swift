import SwiftUI

struct CircularAddButton: View {
    let accent: Color
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircularAddButtonLabel(accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct CircularAddButtonLabel: View {
    let accent: Color

    var body: some View {
        Image(systemName: "plus")
            .font(.body.weight(.semibold))
            .foregroundStyle(accent)
            .frame(width: 32, height: 32)
            .background(.thinMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .frame(width: 40, height: 40)
    }
}
