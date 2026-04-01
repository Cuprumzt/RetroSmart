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

    init(device: DeviceRecord) {
        self.device = device
        _customName = State(initialValue: device.customName)
        _iconSystemName = State(initialValue: device.iconSystemName)
        _assignedTypeID = State(initialValue: device.assignedTypeID)
    }

    var body: some View {
        List {
            Section("Metadata") {
                TextField("Name", text: $customName)

                Picker("Assigned Type", selection: $assignedTypeID) {
                    ForEach(appModel.configRegistry.loadedConfigs) { loadedConfig in
                        Text(loadedConfig.config.module.displayName)
                            .tag(loadedConfig.config.module.typeID)
                    }
                }
            }

            if assignedTypeID != device.advertisedTypeID {
                Section {
                    Label("Assigned type differs from the ESP32’s advertised device type. This is allowed for prototyping, but the rendered controls may not match the hardware.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("Icon") {
                IconPickerView(
                    selectedSymbol: $iconSystemName,
                    suggestions: appModel.configRegistry.config(for: assignedTypeID)?.config.ui.iconSuggestions ?? []
                )
            }

            if let loadedConfig = appModel.configRegistry.config(for: assignedTypeID) {
                Section("Pinout") {
                    ForEach(loadedConfig.config.hardware.pinout.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                        LabeledContent(item.key, value: item.value)
                    }
                }

                Section("Configuration") {
                    ConfigTextView(text: loadedConfig.rawYAML)
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
            }
        }
        .confirmationDialog(
            "Remove this device? Any automations that reference it will also be deleted.",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Device", role: .destructive) {
                removeDevice()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func applyChanges() {
        device.customName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        device.iconSystemName = iconSystemName
        device.assignedTypeID = assignedTypeID
        try? modelContext.save()
        dismiss()
    }

    private func removeDevice() {
        let linkedAutomations = automations.filter {
            $0.triggerDeviceID == device.deviceID || $0.actionDeviceID == device.deviceID
        }

        linkedAutomations.forEach(modelContext.delete)
        modelContext.delete(device)
        try? modelContext.save()
        dismiss()
    }
}
