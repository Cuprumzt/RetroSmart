import SwiftUI

struct AIPlaceholderView: View {
    private let cards: [(title: String, subtitle: String, icon: String)] = [
        ("Create adaptor with AI", "Future workflow for describing appliance geometry, mounting constraints, and retrofit goals.", "square.3.layers.3d"),
        ("Generate module code with AI", "Future workflow for turning validated configs and pinouts into firmware starting points.", "cpu"),
        ("Coming later", "Reference photo upload, dimension capture, and creator tooling will live here in later iterations.", "sparkles"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RetroSmart AI")
                        .font(.largeTitle.weight(.semibold))
                    Text("This stays intentionally non-functional in v1. It marks the future workflow surface without hiding the current prototype behind unfinished generation features.")
                        .foregroundStyle(.secondary)
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.2),
                                    Color(uiColor: .secondarySystemBackground),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                }

                ForEach(cards, id: \.title) { card in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(card.title, systemImage: card.icon)
                            .font(.headline)
                        Text(card.subtitle)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("RetroSmart AI")
    }
}
