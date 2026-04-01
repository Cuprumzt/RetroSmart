import SwiftData
import SwiftUI

struct ConfigLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: [SortDescriptor(\ImportedDeviceTypeRecord.importedAt, order: .forward)]) private var importedConfigs: [ImportedDeviceTypeRecord]
    @Query private var devices: [DeviceRecord]

    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Built-in Types") {
                ForEach(appModel.configRegistry.loadedConfigs.filter { $0.source == .builtIn }) { loadedConfig in
                    NavigationLink {
                        ConfigDetailView(loadedConfig: loadedConfig)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loadedConfig.config.module.displayName)
                            Text(loadedConfig.config.module.typeID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Imported Types") {
                if importedConfigs.isEmpty {
                    Text("No imported types yet.")
                        .foregroundStyle(.secondary)
                }

                ForEach(importedConfigs) { record in
                    if let loadedConfig = appModel.configRegistry.config(for: record.typeID) {
                        NavigationLink {
                            ConfigDetailView(loadedConfig: loadedConfig)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loadedConfig.config.module.displayName)
                                Text("\(record.typeID) • \(record.sourceName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if assignedCount(for: record.typeID) > 0 {
                                    Text("Assigned to \(assignedCount(for: record.typeID)) device(s)")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(record)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Module Types")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Type Library", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") {
                errorMessage = nil
            }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func assignedCount(for typeID: String) -> Int {
        devices.filter { $0.assignedTypeID == typeID }.count
    }

    private func delete(_ record: ImportedDeviceTypeRecord) {
        do {
            try appModel.configRegistry.deleteImportedConfig(
                typeID: record.typeID,
                assignedDeviceCount: assignedCount(for: record.typeID),
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ConfigDetailView: View {
    let loadedConfig: LoadedModuleConfig

    var body: some View {
        List {
            Section("Metadata") {
                LabeledContent("Display Name", value: loadedConfig.config.module.displayName)
                LabeledContent("Type ID", value: loadedConfig.config.module.typeID)
                LabeledContent("Category", value: loadedConfig.config.module.category)
                LabeledContent("Source", value: loadedConfig.source.rawValue)
            }

            Section("Pinout") {
                ForEach(loadedConfig.config.hardware.pinout.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                    LabeledContent(item.key, value: item.value)
                }
            }

            Section("YAML") {
                ConfigTextView(text: loadedConfig.rawYAML)
            }
        }
        .navigationTitle(loadedConfig.config.module.displayName)
    }
}
