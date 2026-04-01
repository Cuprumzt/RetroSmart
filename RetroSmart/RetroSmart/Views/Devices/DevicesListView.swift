import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DevicesListView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\DeviceRecord.insertionIndex, order: .forward)]) private var devices: [DeviceRecord]

    @State private var showingScanner = false
    @State private var showingPasteImporter = false
    @State private var showingFileImporter = false
    @State private var showingConfigLibrary = false
    @State private var importAlertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if devices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No RetroSmart devices yet")
                            .font(.headline)
                        Text("Use the plus button to add a module or import a type.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14),
                        ],
                        spacing: 14
                    ) {
                        ForEach(devices) { device in
                            NavigationLink {
                                DeviceDetailView(device: device)
                            } label: {
                                DeviceGridCard(device: device)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add nearby device", systemImage: "dot.radiowaves.left.and.right") {
                        showingScanner = true
                    }
                    Button("Import config from file", systemImage: "square.and.arrow.down") {
                        showingFileImporter = true
                    }
                    Button("Paste YAML config", systemImage: "doc.text") {
                        showingPasteImporter = true
                    }
                    Divider()
                    Button("Manage module types", systemImage: "square.stack.3d.up") {
                        showingConfigLibrary = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            NavigationStack {
                NearbyDeviceScannerView()
            }
        }
        .sheet(isPresented: $showingPasteImporter) {
            NavigationStack {
                YAMLPasteImportView()
            }
        }
        .sheet(isPresented: $showingConfigLibrary) {
            NavigationStack {
                ConfigLibraryView()
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.yamlFile, .plainText],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let fileURL = try result.get().first else {
                    return
                }
                let hasAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                let yamlText = try String(contentsOf: fileURL)
                let imported = try appModel.configRegistry.importConfig(
                    yamlText: yamlText,
                    sourceName: fileURL.lastPathComponent,
                    modelContext: modelContext
                )
                importAlertMessage = "Imported \(imported.module.displayName). Re-importing the same type_id will replace the active definition globally."
            } catch {
                importAlertMessage = error.localizedDescription
            }
        }
        .alert("Config Import", isPresented: .constant(importAlertMessage != nil), actions: {
            Button("OK") {
                importAlertMessage = nil
            }
        }, message: {
            Text(importAlertMessage ?? "")
        })
    }
}

private struct DeviceGridCard: View {
    @EnvironmentObject private var appModel: AppModel
    let device: DeviceRecord

    private var loadedConfig: LoadedModuleConfig? {
        appModel.configRegistry.config(for: device.assignedTypeID)
    }

    private var connectionState: DeviceConnectionState {
        appModel.bleManager.connectionStates[device.deviceID] ?? .disconnected
    }

    private var liveState: LiveDeviceState? {
        appModel.bleManager.liveStates[device.deviceID]
    }

    private var previewReading: ReadingPreview? {
        guard let config = loadedConfig?.config else {
            return nil
        }

        guard config.module.category == "sensor" else {
            return nil
        }

        guard connectionState == .connected else {
            return nil
        }

        guard let widget = firstReadingWidget(in: config.ui.devicePage.widgets) else {
            return nil
        }

        guard let source = widget.source, let value = liveState?.values[source] else {
            return ReadingPreview(title: widget.label ?? "Reading", value: "Waiting", subtitle: nil)
        }

        let valueText = value.stringValue + (widget.unit.map { " \($0)" } ?? "")
        return ReadingPreview(
            title: widget.label ?? "Reading",
            value: valueText,
            subtitle: nil
        )
    }

    private var statusIconName: String? {
        switch connectionState {
        case .connected:
            return nil
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .disconnected:
            return "wifi.slash"
        }
    }

    private var statusColor: Color {
        switch connectionState {
        case .connected:
            return .clear
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        }
    }

    private var cardSubtitle: String? {
        guard let config = loadedConfig?.config else {
            return nil
        }

        if config.module.category == "sensor" {
            return nil
        }

        return config.module.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: device.iconSystemName)
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer(minLength: 8)

                if let previewReading {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(previewReading.value)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        Text(previewReading.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else if let statusIconName {
                    Image(systemName: statusIconName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 30, height: 30)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.customName)
                    .font(.headline)
                    .lineLimit(2)
                if let cardSubtitle {
                    Text(cardSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if connectionState != .connected {
                    Text(connectionState == .connecting ? "Reconnecting" : "Offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func firstReadingWidget(in widgets: [WidgetConfig]) -> WidgetConfig? {
        for widget in widgets {
            if widget.type == .reading {
                return widget
            }

            if let nested = firstReadingWidget(in: widget.widgets) {
                return nested
            }
        }

        return nil
    }
}

private struct ReadingPreview {
    let title: String
    let value: String
    let subtitle: String?
}

private extension UTType {
    static var yamlFile: UTType {
        UTType(filenameExtension: "yaml") ?? .plainText
    }
}
