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
                Text("RetroSmart AI")
                    .font(.largeTitle.weight(.semibold))

                Text("This tab is intentionally a placeholder in v1. It communicates the future product direction without adding unfinished generation workflows into the prototype.")
                    .foregroundStyle(.secondary)

                ForEach(cards, id: \.title) { card in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(card.title, systemImage: card.icon)
                            .font(.headline)
                        Text(card.subtitle)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle("RetroSmart AI")
    }
}
