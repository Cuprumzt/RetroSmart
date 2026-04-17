import SwiftData
import SwiftUI

struct YAMLPasteImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel

    @State private var yamlText = ""
    @State private var sourceName = "Pasted YAML"
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Paste YAML")
                        .font(.title3.weight(.semibold))
                        .fontDesign(.rounded)
                }
                .padding(20)
                .retroSmartSurface(tone: .accent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Source") {
                TextField("Label", text: $sourceName)
            }

            Section("YAML") {
                ZStack(alignment: .topLeading) {
                    if yamlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("schema_version: 1\nmodule:\n  type_id: ...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                    }

                    TextEditor(text: $yamlText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 280)
                }
                .padding(8)
                .retroSmartSurface(tone: .subdued, cornerRadius: 20, shadow: false)
            }
        }
        .scrollContentBackground(.hidden)
        .retroSmartScreenBackground()
        .tint(RetroSmartTheme.accent)
        .navigationTitle("Paste YAML")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Import") {
                    importConfig()
                }
                .disabled(yamlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("YAML Import", isPresented: messageAlertIsPresented, actions: {
            Button("OK") {
                let success = message?.hasPrefix("Imported") == true
                message = nil
                if success {
                    dismiss()
                }
            }
        }, message: {
            Text(message ?? "")
        })
    }

    private func importConfig() {
        do {
            let config = try appModel.configRegistry.importConfig(
                yamlText: yamlText,
                sourceName: sourceName,
                modelContext: modelContext
            )
            message = "Imported \(config.module.displayName) successfully."
        } catch {
            message = error.localizedDescription
        }
    }

    private var messageAlertIsPresented: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { isPresented in
                if !isPresented {
                    message = nil
                }
            }
        )
    }
}
