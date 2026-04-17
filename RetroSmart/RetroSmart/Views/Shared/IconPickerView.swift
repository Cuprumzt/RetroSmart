import SwiftUI

struct IconPickerView: View {
    @Binding var selectedSymbol: String
    let suggestions: [String]

    private var symbols: [String] {
        let merged = suggestions + IconCatalog.defaultSymbols
        var seen: Set<String> = []
        return merged.filter { seen.insert($0).inserted }
    }

    private let columns = [GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    selectedSymbol = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(selectedSymbol == symbol ? RetroSmartTheme.accentStrong : .primary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 16)
                    .retroSmartSurface(
                        tone: selectedSymbol == symbol ? .accent : .subdued,
                        cornerRadius: 18,
                        shadow: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
            }
        }
    }
}
