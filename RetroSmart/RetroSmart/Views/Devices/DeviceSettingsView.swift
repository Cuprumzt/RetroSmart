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

    var body: some View {
        List {
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

            if assignedTypeID != device.advertisedTypeID {
                Section {
                    Label("Assigned type differs from the ESP32’s advertised device type. This is allowed for prototyping, but the rendered controls may not match the hardware.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if isEditable("custom_icon") {
                Section("Icon") {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconSystemName)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(Color.accentColor.opacity(0.14))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose Icon")
                                    .foregroundStyle(.primary)
                                Text(iconSystemName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
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
        .navigationTitle("Device Settings")
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

private struct IconSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSymbol: String
    let suggestions: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: selectedSymbol)
                        .font(.title2)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Icon")
                            .font(.headline)
                        Text(selectedSymbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                IconPickerView(
                    selectedSymbol: $selectedSymbol,
                    suggestions: suggestions
                )
            }
            .padding()
        }
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
