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
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.14))
                    .foregroundStyle(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            case .standard:
                Text(labelText)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .frame(height: 16)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.14))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            case .deviceDetail:
                Label(labelText, systemImage: iconName)
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.14))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var color: Color {
        switch state {
        case .connected:
            return RetroSmartTheme.success
        case .connecting:
            return RetroSmartTheme.warning
        case .disconnected:
            return RetroSmartTheme.quiet
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
        case .standard:
            switch state {
            case .connected:
                return "Live"
            case .connecting:
                return "Linking"
            case .disconnected:
                return "Offline"
            }
        case .deviceDetail:
            switch state {
            case .connected:
                return "Connected"
            case .connecting:
                return "Connecting"
            case .disconnected:
                return "Disconnected"
            }
        case .iconOnly:
            return state.label
        }
    }

    private var accessibilityText: String {
        switch style {
        case .standard:
            switch state {
            case .connected:
                return "Connected"
            case .connecting:
                return "Connecting"
            case .disconnected:
                return "Offline"
            }
        case .deviceDetail, .iconOnly:
            return labelText
        }
    }
}
