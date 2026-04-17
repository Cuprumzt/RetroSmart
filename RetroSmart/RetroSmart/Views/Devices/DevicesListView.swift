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

    private var connectedDeviceCount: Int {
        devices.filter { appModel.bleManager.connectionStates[$0.deviceID] == .connected }.count
    }

    private var availableTypeCount: Int {
        appModel.configRegistry.loadedConfigs.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DevicesOverviewCard(
                    deviceCount: devices.count,
                    connectedCount: connectedDeviceCount,
                    typeCount: availableTypeCount
                )

                if devices.isEmpty {
                    RetroSmartEmptyStateCard(
                        title: "No RetroSmart devices yet",
                        message: "Use + to add or import one.",
                        systemImage: "switch.2",
                        tone: .accent
                    )
                } else {
                    RetroSmartSectionHeader(
                        eyebrow: "Library",
                        title: "Your devices"
                    )

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
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .retroSmartScreenBackground()
        .navigationTitle("RetroSmart")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addMenu
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
        .alert("Config Import", isPresented: importAlertIsPresented, actions: {
            Button("OK") {
                importAlertMessage = nil
            }
        }, message: {
            Text(importAlertMessage ?? "")
        })
    }

    private var addMenu: some View {
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
                .font(.headline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(RetroSmartTheme.accent.opacity(0.14))
                .foregroundStyle(RetroSmartTheme.accentStrong)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var importAlertIsPresented: Binding<Bool> {
        Binding(
            get: { importAlertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importAlertMessage = nil
                }
            }
        )
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

        guard config.module.category == "sensor", connectionState == .connected else {
            return nil
        }

        guard let widget = firstReadingWidget(in: config.ui.devicePage.widgets) else {
            return nil
        }

        guard let source = widget.source, let value = liveState?.values[source] else {
            return ReadingPreview(value: "Waiting")
        }

        let valueText = formattedPreviewValue(for: widget, value: value)
        return ReadingPreview(value: valueText)
    }

    private var cardTone: RetroSmartSurfaceTone {
        switch connectionState {
        case .connected:
            return previewReading == nil ? .neutral : .accent
        case .connecting:
            return .warning
        case .disconnected:
            return .neutral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                iconTile

                Spacer(minLength: 4)

                if let previewReading {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(previewReading.value)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .frame(width: 82, alignment: .trailing)
                    }
                } else {
                    StatusBadge(state: connectionState, style: .standard)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.customName)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .padding(16)
        .retroSmartSurface(tone: cardTone)
    }

    private var iconTile: some View {
        Image(systemName: device.iconSystemName)
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)
            .background(RetroSmartTheme.accent.opacity(0.14))
            .foregroundStyle(RetroSmartTheme.accentStrong)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func formattedPreviewValue(for widget: WidgetConfig, value: JSONValue) -> String {
        if widget.unit?.uppercased() == "C" {
            if let numericValue = value.doubleValue {
                return numericValue.formatted(.number.precision(.fractionLength(1))) + "°C"
            }

            return value.stringValue + "°C"
        }

        return value.stringValue + (widget.unit.map { " \($0)" } ?? "")
    }
}

private struct DevicesOverviewCard: View {
    let deviceCount: Int
    let connectedCount: Int
    let typeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("RetroSmart Home")
                    .font(.title2.weight(.semibold))
                    .fontDesign(.rounded)

                Spacer()

                RetroSmartTag(title: "\(typeCount) types", tone: .subdued)
            }

            HStack(spacing: 12) {
                RetroSmartMetricPill(title: "Devices", value: "\(deviceCount)")
                RetroSmartMetricPill(
                    title: "Live",
                    value: "\(connectedCount)",
                    tone: connectedCount == 0 ? .subdued : .success
                )
            }
        }
        .padding(22)
        .retroSmartSurface(tone: .accent)
    }
}

private struct ReadingPreview {
    let value: String
}

private extension UTType {
    static var yamlFile: UTType {
        UTType(filenameExtension: "yaml") ?? .plainText
    }
}
