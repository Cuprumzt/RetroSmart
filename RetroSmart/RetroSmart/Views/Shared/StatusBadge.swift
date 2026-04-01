import SwiftUI

enum StatusBadgeStyle {
    case standard
    case iconOnly
    case deviceDetail
}

struct StatusBadge: View {
    let state: DeviceConnectionState
    var style: StatusBadgeStyle = .standard

    var body: some View {
        Group {
            switch style {
            case .iconOnly:
                Image(systemName: iconName)
                    .font(.body.weight(.semibold))
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.16))
                    .foregroundStyle(color)
                    .clipShape(Circle())
            case .standard, .deviceDetail:
                Label(labelText, systemImage: iconName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.16))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }
        }
        .accessibilityLabel(labelText)
    }

    private var color: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .secondary
        }
    }

    private var iconName: String {
        switch state {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .disconnected:
            return "wifi.slash"
        }
    }

    private var labelText: String {
        switch style {
        case .deviceDetail:
            switch state {
            case .connected:
                return "Connected"
            case .connecting, .disconnected:
                return "Disconnected"
            }
        case .standard, .iconOnly:
            return state.label
        }
    }
}
