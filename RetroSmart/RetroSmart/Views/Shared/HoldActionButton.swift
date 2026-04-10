import SwiftUI

struct HoldActionButton: View {
    let title: String
    let systemImage: String?
    let tint: Color
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false
    
    private var minimumHeight: CGFloat {
        systemImage == nil ? 56 : 96
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
            }

            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight)
        .padding(.vertical, 16)
        .background(shape.fill(isPressed ? tint.opacity(0.22) : tint.opacity(0.12)))
        .foregroundStyle(tint)
        .overlay {
            shape.stroke(tint.opacity(0.25), lineWidth: 1)
        }
        .contentShape(shape)
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
