import SwiftUI

struct HoldActionButton: View {
    @Environment(\.isEnabled) private var isEnabled

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
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .symbolVariant(.fill)
            }

            Text(title)
                .font(.headline)
                .fontDesign(.rounded)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight)
        .padding(.vertical, 18)
        .background(shape.fill(backgroundFill))
        .foregroundStyle(foregroundStyle)
        .overlay {
            shape.stroke(borderColor, lineWidth: 1)
        }
        .contentShape(shape)
        .scaleEffect(isPressed && isEnabled ? 0.985 : 1)
        .shadow(color: .black.opacity(isEnabled ? 0.08 : 0), radius: 14, y: 8)
        .animation(.snappy(duration: 0.18), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled, !isPressed else { return }
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

    private var backgroundFill: LinearGradient {
        let baseTint = isEnabled ? tint : RetroSmartTheme.quiet
        let topOpacity = isPressed ? 0.30 : 0.18
        let bottomOpacity = isPressed ? 0.22 : 0.10

        return LinearGradient(
            colors: [
                baseTint.opacity(topOpacity),
                baseTint.opacity(bottomOpacity),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var foregroundStyle: Color {
        isEnabled ? tint : RetroSmartTheme.quiet
    }

    private var borderColor: Color {
        (isEnabled ? tint : RetroSmartTheme.quiet).opacity(0.24)
    }
}
