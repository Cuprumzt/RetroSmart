import SwiftData
import SwiftUI

struct AutomationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: [SortDescriptor(\DeviceRecord.insertionIndex, order: .forward)]) private var devices: [DeviceRecord]

    private let editingRule: AutomationRuleRecord?

    @State private var name = ""
    @State private var triggerDeviceID = ""
    @State private var triggerSourceID = ""
    @State private var comparison = AutomationComparisonKind.above
    @State private var triggerValue = ""
    @State private var actionDeviceID = ""
    @State private var actionID = ""
    @State private var actionValue = ""
    @State private var isEnabled = true

    init(editingRule: AutomationRuleRecord? = nil) {
        self.editingRule = editingRule
        _name = State(initialValue: editingRule?.name ?? "")
        _triggerDeviceID = State(initialValue: editingRule?.triggerDeviceID ?? "")
        _triggerSourceID = State(initialValue: editingRule?.triggerSourceID ?? "")
        _comparison = State(initialValue: AutomationComparisonKind(rawValue: editingRule?.comparison ?? "") ?? .above)
        _triggerValue = State(initialValue: editingRule?.triggerValue ?? "")
        _actionDeviceID = State(initialValue: editingRule?.actionDeviceID ?? "")
        _actionID = State(initialValue: editingRule?.actionID ?? "")
        _actionValue = State(initialValue: editingRule?.actionValue ?? "")
        _isEnabled = State(initialValue: editingRule?.isEnabled ?? true)
    }

    private var selectedTriggerConfig: LoadedModuleConfig? {
        guard let device = devices.first(where: { $0.deviceID == triggerDeviceID }) else { return nil }
        return appModel.configRegistry.config(for: device.assignedTypeID)
    }

    private var selectedActionConfig: LoadedModuleConfig? {
        guard let device = devices.first(where: { $0.deviceID == actionDeviceID }) else { return nil }
        return appModel.configRegistry.config(for: device.assignedTypeID)
    }

    private var triggerOptions: [ReadingCapability] {
        selectedTriggerConfig?.config.capabilities.readings.filter {
            selectedTriggerConfig?.config.automation.triggers.contains($0.id) ?? true
        } ?? []
    }

    private var actionOptions: [ActionCapability] {
        selectedActionConfig?.config.capabilities.actions.filter {
            selectedActionConfig?.config.automation.actions.contains($0.id) ?? true
        } ?? []
    }

    private var selectedActionPayloadType: String {
        actionOptions.first(where: { $0.id == actionID })?.payload.type ?? "none"
    }

    var body: some View {
        Form {
            Section("Rule") {
                TextField("Name", text: $name)
                Toggle("Enabled", isOn: $isEnabled)
            }

            Section("Trigger") {
                Picker("Device", selection: $triggerDeviceID) {
                    Text("Select device").tag("")
                    ForEach(devices.filter { deviceSupportsTriggers($0) }) { device in
                        Text(device.customName).tag(device.deviceID)
                    }
                }

                Picker("Reading", selection: $triggerSourceID) {
                    Text("Select reading").tag("")
                    ForEach(triggerOptions) { reading in
                        Text(reading.label).tag(reading.id)
                    }
                }
                .disabled(triggerOptions.isEmpty)

                Picker("Condition", selection: $comparison) {
                    ForEach(AutomationComparisonKind.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }

                TextField("Threshold or value", text: $triggerValue)
                    .keyboardType(.numbersAndPunctuation)
            }

            Section("Action") {
                Picker("Device", selection: $actionDeviceID) {
                    Text("Select device").tag("")
                    ForEach(devices.filter { deviceSupportsActions($0) }) { device in
                        Text(device.customName).tag(device.deviceID)
                    }
                }

                Picker("Action", selection: $actionID) {
                    Text("Select action").tag("")
                    ForEach(actionOptions) { action in
                        Text(action.label).tag(action.id)
                    }
                }
                .disabled(actionOptions.isEmpty)

                if selectedActionPayloadType != "none" {
                    TextField("Action value", text: $actionValue)
                        .keyboardType(.numbersAndPunctuation)
                }
            }

            Section {
                Text("Automations execute locally only while the app is foregrounded and connected devices are available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(editingRule == nil ? "New Automation" : "Edit Automation")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveRule()
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: triggerDeviceID) { _, newValue in
            if !triggerOptions.contains(where: { $0.id == triggerSourceID }) {
                triggerSourceID = triggerOptions.first?.id ?? ""
            }
            if name.isEmpty, let device = devices.first(where: { $0.deviceID == newValue }) {
                name = "\(device.customName) automation"
            }
        }
        .onChange(of: actionDeviceID) { _, _ in
            if !actionOptions.contains(where: { $0.id == actionID }) {
                actionID = actionOptions.first?.id ?? ""
            }
        }
        .onAppear {
            if triggerDeviceID.isEmpty {
                triggerDeviceID = devices.first(where: deviceSupportsTriggers)?.deviceID ?? ""
            }
            if actionDeviceID.isEmpty {
                actionDeviceID = devices.first(where: deviceSupportsActions)?.deviceID ?? ""
            }
            if triggerSourceID.isEmpty {
                triggerSourceID = triggerOptions.first?.id ?? ""
            }
            if actionID.isEmpty {
                actionID = actionOptions.first?.id ?? ""
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !triggerDeviceID.isEmpty &&
            !triggerSourceID.isEmpty &&
            !triggerValue.isEmpty &&
            !actionDeviceID.isEmpty &&
            !actionID.isEmpty
    }

    private func deviceSupportsTriggers(_ device: DeviceRecord) -> Bool {
        guard let config = appModel.configRegistry.config(for: device.assignedTypeID)?.config else {
            return false
        }
        return !config.automation.triggers.isEmpty
    }

    private func deviceSupportsActions(_ device: DeviceRecord) -> Bool {
        guard let config = appModel.configRegistry.config(for: device.assignedTypeID)?.config else {
            return false
        }
        return !config.automation.actions.isEmpty
    }

    private func saveRule() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingRule {
            editingRule.name = trimmedName
            editingRule.isEnabled = isEnabled
            editingRule.triggerDeviceID = triggerDeviceID
            editingRule.triggerSourceID = triggerSourceID
            editingRule.comparison = comparison.rawValue
            editingRule.triggerValue = triggerValue
            editingRule.actionDeviceID = actionDeviceID
            editingRule.actionID = actionID
            editingRule.actionValue = selectedActionPayloadType == "none" ? nil : actionValue
        } else {
            modelContext.insert(
                AutomationRuleRecord(
                    name: trimmedName,
                    isEnabled: isEnabled,
                    triggerDeviceID: triggerDeviceID,
                    triggerSourceID: triggerSourceID,
                    comparison: comparison.rawValue,
                    triggerValue: triggerValue,
                    actionDeviceID: actionDeviceID,
                    actionID: actionID,
                    actionValue: selectedActionPayloadType == "none" ? nil : actionValue
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }
}
