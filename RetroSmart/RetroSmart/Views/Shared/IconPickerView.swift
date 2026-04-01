import SwiftUI

struct IconPickerView: View {
    @Binding var selectedSymbol: String
    let suggestions: [String]

    private var symbols: [String] {
        let merged = suggestions + IconCatalog.defaultSymbols
        var seen: Set<String> = []
        return merged.filter { seen.insert($0).inserted }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    selectedSymbol = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedSymbol == symbol ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
