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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DevicesOverviewCard(
                    deviceCount: devices.count,
                    connectedCount: connectedDeviceCount
                )

                if devices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("No RetroSmart devices yet", systemImage: "switch.2")
                            .font(.headline)
                        Text("Use the plus button to add a nearby module or import a type definition.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.14),
                                        Color(uiColor: .secondarySystemGroupedBackground),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                    }
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
        .navigationTitle("RetroSmart")
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
        .alert("Config Import", isPresented: importAlertIsPresented, actions: {
            Button("OK") {
                importAlertMessage = nil
            }
        }, message: {
            Text(importAlertMessage ?? "")
        })
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
    @Environment(\.colorScheme) private var colorScheme
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

    private var cardGradient: LinearGradient {
        let accent = Color.accentColor
        switch connectionState {
        case .connected:
            return LinearGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.22 : 0.14), panelColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting:
            return LinearGradient(
                colors: [Color.orange.opacity(colorScheme == .dark ? 0.18 : 0.12), panelColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .disconnected:
            return LinearGradient(
                colors: [panelColor, panelInsetColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var panelColor: Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.10, blue: 0.16)
            : Color(red: 0.92, green: 0.95, blue: 0.99)
    }

    private var panelInsetColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.15, blue: 0.22)
            : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: device.iconSystemName)
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(panelInsetColor)
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
                    Label(connectionState == .connecting ? "Connecting" : "Offline", systemImage: statusIconName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(panelInsetColor)
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }
            }

            Spacer(minLength: 0)

            Text(device.customName)
                .font(.headline)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardGradient)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 18, y: 10)
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

private struct DevicesOverviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let deviceCount: Int
    let connectedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RetroSmart Home")
                .font(.title2.weight(.semibold))

            HStack(spacing: 12) {
                summaryValue(title: "Devices", value: "\(deviceCount)")
                summaryValue(title: "Live", value: "\(connectedCount)")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.16),
                            panelColor,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.06), radius: 20, y: 10)
    }

    private func summaryValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(panelInsetColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var panelColor: Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.10, blue: 0.16)
            : Color(red: 0.92, green: 0.95, blue: 0.99)
    }

    private var panelInsetColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.15, blue: 0.22)
            : Color.white
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
