import SwiftUI

struct ConfigTextView: View {
    let text: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .frame(minHeight: 140, alignment: .topLeading)
        .retroSmartSurface(tone: .subdued, cornerRadius: 18, shadow: false)
    }
}
