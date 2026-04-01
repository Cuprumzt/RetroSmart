import SwiftUI

struct HoldActionButton: View {
    let title: String
    let tint: Color
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPressed ? tint.opacity(0.22) : tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPress()
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        onRelease()
                    }
            )
    }
}
