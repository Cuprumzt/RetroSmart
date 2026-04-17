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
            Section {
                ConfigLibrarySummaryCard(
                    builtInCount: appModel.configRegistry.loadedConfigs.filter { $0.source == .builtIn }.count,
                    importedCount: importedConfigs.count
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Built-in Types") {
                ForEach(appModel.configRegistry.loadedConfigs.filter { $0.source == .builtIn }) { loadedConfig in
                    NavigationLink {
                        ConfigDetailView(loadedConfig: loadedConfig)
                    } label: {
                        ConfigLibraryRow(
                            title: loadedConfig.config.module.displayName,
                            subtitle: loadedConfig.config.module.typeID,
                            detail: loadedConfig.config.module.category.capitalized,
                            tone: .neutral
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section("Imported Types") {
                if importedConfigs.isEmpty {
                    RetroSmartEmptyStateCard(
                        title: "No imported types yet",
                        message: nil,
                        systemImage: "square.stack.3d.up",
                        tone: .neutral
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                ForEach(importedConfigs) { record in
                    if let loadedConfig = appModel.configRegistry.config(for: record.typeID) {
                        NavigationLink {
                            ConfigDetailView(loadedConfig: loadedConfig)
                        } label: {
                            ConfigLibraryRow(
                                title: loadedConfig.config.module.displayName,
                                subtitle: "\(record.typeID) • \(record.sourceName)",
                                detail: assignedCount(for: record.typeID) > 0 ? "Assigned to \(assignedCount(for: record.typeID)) device(s)" : "Imported",
                                tone: assignedCount(for: record.typeID) > 0 ? .warning : .accent
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(record)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        ConfigLibraryRow(
                            title: record.typeID,
                            subtitle: record.sourceName,
                            detail: "Stored import is no longer valid and can only be deleted.",
                            tone: .warning
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
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
        .scrollContentBackground(.hidden)
        .retroSmartScreenBackground()
        .navigationTitle("Module Types")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Type Library", isPresented: errorAlertIsPresented, actions: {
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

    private var errorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }
}

private struct ConfigLibrarySummaryCard: View {
    let builtInCount: Int
    let importedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Config library")
                    .font(.title3.weight(.semibold))
                    .fontDesign(.rounded)

                Spacer()

                RetroSmartTag(title: "YAML", tone: .subdued)
            }

            HStack(spacing: 12) {
                RetroSmartMetricPill(title: "Built-in", value: "\(builtInCount)")
                RetroSmartMetricPill(title: "Imported", value: "\(importedCount)", tone: importedCount == 0 ? .subdued : .accent)
            }
        }
        .padding(20)
        .retroSmartSurface(tone: .accent)
    }
}

private struct ConfigLibraryRow: View {
    let title: String
    let subtitle: String
    let detail: String
    let tone: RetroSmartSurfaceTone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .fontDesign(.rounded)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.caption2.weight(.medium))
                .foregroundStyle(detailToneColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .retroSmartSurface(tone: tone, cornerRadius: 20, shadow: false)
    }

    private var detailToneColor: Color {
        switch tone {
        case .accent:
            return RetroSmartTheme.accentStrong
        case .warning:
            return RetroSmartTheme.warning
        default:
            return .secondary
        }
    }
}

private struct ConfigDetailView: View {
    let loadedConfig: LoadedModuleConfig

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loadedConfig.config.module.displayName)
                        .font(.title3.weight(.semibold))
                        .fontDesign(.rounded)

                    RetroSmartTag(title: loadedConfig.source.rawValue, systemImage: "doc.text", tone: loadedConfig.source == .builtIn ? .neutral : .accent)
                }
                .padding(20)
                .retroSmartSurface(tone: loadedConfig.source == .builtIn ? .neutral : .accent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Module Information") {
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
        .scrollContentBackground(.hidden)
        .retroSmartScreenBackground()
        .navigationTitle(loadedConfig.config.module.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
