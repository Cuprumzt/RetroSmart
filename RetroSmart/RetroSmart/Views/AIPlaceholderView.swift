import SwiftUI

struct AIPlaceholderView: View {
    private let cards: [(title: String, subtitle: String, detail: String, icon: String)] = [
        (
            "Create adaptor with AI",
            "Adaptor workflow",
            "Turn a module idea into a clean YAML adaptor draft with pins, readings, actions, and UI defaults.",
            "square.3.layers.3d"
        ),
        (
            "Generate module code with AI",
            "Firmware workflow",
            "Use the adaptor definition to sketch Arduino-based ESP32 firmware with the expected BLE contract and state payloads.",
            "cpu"
        ),
        (
            "Coming later",
            "Photos and dimensions",
            "Use reference photos and rough measurements to help map controls, naming, and enclosure-aware module setup.",
            "sparkles"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RetroSmart AI")
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.rounded)

                    Text("A future workspace for faster adaptor setup, firmware scaffolding, and hardware-aware suggestions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    RetroSmartTag(title: "Placeholder", systemImage: "sparkles", tone: .warning)
                }
                .padding(24)
                .retroSmartSurface(tone: .warning)

                RetroSmartSectionHeader(
                    eyebrow: "Future",
                    title: "Planned workflows",
                    subtitle: "These are the first AI-assisted flows planned for RetroSmart."
                )

                ForEach(cards, id: \.title) { card in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(card.title, systemImage: card.icon)
                            .font(.headline)
                            .fontDesign(.rounded)

                        Text(card.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(card.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .retroSmartSurface()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .retroSmartScreenBackground()
        .navigationTitle("RetroSmart AI")
        .navigationBarTitleDisplayMode(.large)
    }
}
