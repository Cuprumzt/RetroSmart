import SwiftData
import SwiftUI

struct DeviceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query private var automations: [AutomationRuleRecord]

    let device: DeviceRecord

    @State private var customName: String
    @State private var iconSystemName: String
    @State private var assignedTypeID: String
    @State private var showingDeleteConfirmation = false
    @State private var showingIconPicker = false
    @State private var showingConfiguration = false
    @State private var errorMessage: String?

    init(device: DeviceRecord) {
        self.device = device
        _customName = State(initialValue: device.customName)
        _iconSystemName = State(initialValue: device.iconSystemName)
        _assignedTypeID = State(initialValue: device.assignedTypeID)
    }

    private var loadedConfig: LoadedModuleConfig? {
        appModel.configRegistry.config(for: assignedTypeID)
    }

    private var settingsPageConfig: SettingsPageConfig? {
        loadedConfig?.config.ui.settingsPage
    }

    private var connectionState: DeviceConnectionState {
        appModel.bleManager.connectionStates[device.deviceID] ?? .disconnected
    }

    var body: some View {
        Form {
            Section {
                DeviceSettingsSummaryCard(
                    customName: customName,
                    iconSystemName: iconSystemName,
                    typeLabel: loadedConfig?.config.module.displayName ?? assignedTypeID,
                    connectionState: connectionState
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if assignedTypeID != device.advertisedTypeID {
                Section {
                    Label("Assigned type differs from the advertised type.", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(RetroSmartTheme.warning)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .retroSmartSurface(tone: .warning, cornerRadius: 20, shadow: false)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("Module Information") {
                if isEditable("custom_name") {
                    TextField("Name", text: $customName)
                } else {
                    LabeledContent("Name", value: customName)
                }

                if isEditable("assigned_type") {
                    Picker("Module Type", selection: $assignedTypeID) {
                        ForEach(appModel.configRegistry.loadedConfigs) { loadedConfig in
                            Text(loadedConfig.config.module.displayName)
                                .tag(loadedConfig.config.module.typeID)
                        }
                    }
                } else if let loadedConfig {
                    LabeledContent("Module Type", value: loadedConfig.config.module.displayName)
                }
            }

            if isEditable("custom_icon") {
                Section("Icon") {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconSystemName)
                                .font(.title3.weight(.semibold))
                                .frame(width: 40, height: 40)
                                .background(RetroSmartTheme.accent.opacity(0.14))
                                .foregroundStyle(RetroSmartTheme.accentStrong)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose Icon")
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if settingsPageConfig?.showPinout ?? true, let loadedConfig {
                Section("Pinout") {
                    ForEach(loadedConfig.config.hardware.pinout.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                        LabeledContent(item.key, value: item.value)
                    }
                }
            }

            if settingsPageConfig?.showConfigText ?? true, let loadedConfig {
                Section("Configuration") {
                    DisclosureGroup("Show YAML", isExpanded: $showingConfiguration) {
                        ConfigTextView(text: loadedConfig.rawYAML)
                            .padding(.top, 8)
                    }
                    .tint(.primary)
                }
            }

            Section {
                Button("Remove Device", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .retroSmartScreenBackground()
        .tint(RetroSmartTheme.accent)
        .navigationTitle("Device Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    applyChanges()
                }
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadedConfig == nil)
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            NavigationStack {
                IconSelectionSheet(
                    selectedSymbol: $iconSystemName,
                    suggestions: loadedConfig?.config.ui.iconSuggestions ?? []
                )
            }
        }
        .alert(
            "Remove this device?",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Remove Device", role: .destructive) {
                    removeDevice()
                }
            },
            message: {
                Text("Any automations that reference it will also be deleted.")
            }
        )
        .alert("Device Settings", isPresented: errorAlertIsPresented) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func applyChanges() {
        device.customName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        device.iconSystemName = iconSystemName
        device.assignedTypeID = assignedTypeID

        do {
            try modelContext.save()
            appModel.bleManager.markDeviceRemoved(deviceID: device.deviceID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeDevice() {
        let linkedAutomations = automations.filter {
            $0.triggerDeviceID == device.deviceID || $0.actionDeviceID == device.deviceID
        }

        linkedAutomations.forEach(modelContext.delete)
        modelContext.delete(device)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isEditable(_ field: String) -> Bool {
        settingsPageConfig?.editableFields.contains(field) ?? true
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

private struct DeviceSettingsSummaryCard: View {
    let customName: String
    let iconSystemName: String
    let typeLabel: String
    let connectionState: DeviceConnectionState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconSystemName)
                .font(.title2.weight(.semibold))
                .frame(width: 52, height: 52)
                .background(RetroSmartTheme.accent.opacity(0.14))
                .foregroundStyle(RetroSmartTheme.accentStrong)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(customName)
                    .font(.title3.weight(.semibold))
                    .fontDesign(.rounded)
            }

            Spacer()

            StatusBadge(state: connectionState, style: .deviceDetail)
        }
        .padding(20)
        .retroSmartSurface(tone: connectionState == .connected ? .accent : .neutral)
    }
}

private struct IconSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSymbol: String
    let suggestions: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: selectedSymbol)
                        .font(.title2.weight(.semibold))
                        .frame(width: 46, height: 46)
                        .background(RetroSmartTheme.accent.opacity(0.14))
                        .foregroundStyle(RetroSmartTheme.accentStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Icon")
                            .font(.headline)
                            .fontDesign(.rounded)
                    }
                }
                .padding(18)
                .retroSmartSurface(tone: .accent)

                IconPickerView(
                    selectedSymbol: $selectedSymbol,
                    suggestions: suggestions
                )
            }
            .padding(20)
        }
        .retroSmartScreenBackground()
        .navigationTitle("Choose Icon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
