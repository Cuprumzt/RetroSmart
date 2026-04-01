import SwiftUI
import SwiftData

struct YAMLPasteImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel

    @State private var yamlText = ""
    @State private var sourceName = "Pasted YAML"
    @State private var message: String?

    var body: some View {
        Form {
            Section("Source") {
                TextField("Label", text: $sourceName)
            }

            Section("YAML") {
                TextEditor(text: $yamlText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)
            }

            Section {
                Text("Importing a type with the same `type_id` replaces the active definition globally for all devices assigned to that type.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Paste YAML")
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
        .alert("YAML Import", isPresented: .constant(message != nil), actions: {
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
}
