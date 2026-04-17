import SwiftUI

enum RetroSmartTheme {
    static let accent = Color(red: 0.13, green: 0.54, blue: 0.58)
    static let accentStrong = Color(red: 0.08, green: 0.42, blue: 0.46)
    static let success = Color(red: 0.23, green: 0.58, blue: 0.39)
    static let warning = Color(red: 0.79, green: 0.53, blue: 0.20)
    static let danger = Color(red: 0.72, green: 0.31, blue: 0.27)
    static let quiet = Color(red: 0.43, green: 0.49, blue: 0.58)
}

enum RetroSmartSurfaceTone {
    case neutral
    case accent
    case success
    case warning
    case danger
    case subdued
}

extension View {
    func retroSmartScreenBackground() -> some View {
        modifier(RetroSmartScreenBackgroundModifier())
    }

    func retroSmartSurface(
        tone: RetroSmartSurfaceTone = .neutral,
        cornerRadius: CGFloat = 28,
        shadow: Bool = true
    ) -> some View {
        modifier(
            RetroSmartSurfaceModifier(
                tone: tone,
                cornerRadius: cornerRadius,
                shadow: shadow
            )
        )
    }
}

struct RetroSmartSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RetroSmartTheme.quiet)
                    .tracking(1.1)
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RetroSmartMetricPill: View {
    let title: String
    let value: String
    var tone: RetroSmartSurfaceTone = .subdued

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            Text(value)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .retroSmartSurface(tone: tone, cornerRadius: 20, shadow: false)
    }
}

struct RetroSmartTag: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var systemImage: String?
    var tone: RetroSmartSurfaceTone = .subdued

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch tone {
        case .accent:
            return RetroSmartTheme.accentStrong
        case .success:
            return RetroSmartTheme.success
        case .warning:
            return RetroSmartTheme.warning
        case .danger:
            return RetroSmartTheme.danger
        case .neutral, .subdued:
            return colorScheme == .dark ? .white.opacity(0.84) : .secondary
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .accent:
            return RetroSmartTheme.accent.opacity(colorScheme == .dark ? 0.24 : 0.14)
        case .success:
            return RetroSmartTheme.success.opacity(colorScheme == .dark ? 0.24 : 0.14)
        case .warning:
            return RetroSmartTheme.warning.opacity(colorScheme == .dark ? 0.24 : 0.14)
        case .danger:
            return RetroSmartTheme.danger.opacity(colorScheme == .dark ? 0.24 : 0.14)
        case .neutral, .subdued:
            return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.06)
        }
    }
}

struct RetroSmartEmptyStateCard: View {
    let title: String
    let message: String?
    let systemImage: String
    var tone: RetroSmartSurfaceTone = .accent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .fontDesign(.rounded)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .retroSmartSurface(tone: tone)
    }
}

private struct RetroSmartScreenBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(background.ignoresSafeArea())
    }

    private var background: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.09),
                    Color(red: 0.07, green: 0.09, blue: 0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.99, blue: 1.0),
                Color(red: 0.93, green: 0.95, blue: 0.98),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct RetroSmartSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let tone: RetroSmartSurfaceTone
    let cornerRadius: CGFloat
    let shadow: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: shadow ? 18 : 0, y: shadow ? 10 : 0)
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: fillColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fillColors: [Color] {
        switch (tone, colorScheme) {
        case (.neutral, .dark):
            return [
                Color(red: 0.11, green: 0.13, blue: 0.18),
                Color(red: 0.08, green: 0.10, blue: 0.15),
            ]
        case (.neutral, _):
            return [
                Color.white.opacity(0.98),
                Color(red: 0.94, green: 0.96, blue: 0.99),
            ]
        case (.accent, .dark):
            return [
                Color(red: 0.09, green: 0.18, blue: 0.19),
                Color(red: 0.06, green: 0.12, blue: 0.14),
            ]
        case (.accent, _):
            return [
                Color(red: 0.90, green: 0.97, blue: 0.98),
                Color(red: 0.83, green: 0.93, blue: 0.95),
            ]
        case (.success, .dark):
            return [
                Color(red: 0.10, green: 0.18, blue: 0.13),
                Color(red: 0.08, green: 0.13, blue: 0.10),
            ]
        case (.success, _):
            return [
                Color(red: 0.91, green: 0.97, blue: 0.93),
                Color(red: 0.86, green: 0.95, blue: 0.89),
            ]
        case (.warning, .dark):
            return [
                Color(red: 0.20, green: 0.15, blue: 0.09),
                Color(red: 0.14, green: 0.10, blue: 0.06),
            ]
        case (.warning, _):
            return [
                Color(red: 0.99, green: 0.95, blue: 0.88),
                Color(red: 0.96, green: 0.91, blue: 0.82),
            ]
        case (.danger, .dark):
            return [
                Color(red: 0.20, green: 0.10, blue: 0.10),
                Color(red: 0.15, green: 0.08, blue: 0.08),
            ]
        case (.danger, _):
            return [
                Color(red: 0.99, green: 0.92, blue: 0.91),
                Color(red: 0.97, green: 0.86, blue: 0.84),
            ]
        case (.subdued, .dark):
            return [
                Color.white.opacity(0.08),
                Color.white.opacity(0.04),
            ]
        case (.subdued, _):
            return [
                Color.black.opacity(0.03),
                Color.black.opacity(0.02),
            ]
        }
    }

    private var stroke: Color {
        switch tone {
        case .accent:
            return RetroSmartTheme.accent.opacity(colorScheme == .dark ? 0.36 : 0.20)
        case .success:
            return RetroSmartTheme.success.opacity(colorScheme == .dark ? 0.36 : 0.18)
        case .warning:
            return RetroSmartTheme.warning.opacity(colorScheme == .dark ? 0.34 : 0.18)
        case .danger:
            return RetroSmartTheme.danger.opacity(colorScheme == .dark ? 0.34 : 0.18)
        case .neutral, .subdued:
            return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08)
        }
    }

    private var shadowColor: Color {
        guard shadow else { return .clear }
        return colorScheme == .dark ? .black.opacity(0.24) : .black.opacity(0.06)
    }
}
