import SwiftData
import SwiftUI

struct AutomationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: [SortDescriptor(\DeviceRecord.insertionIndex, order: .forward)]) private var devices: [DeviceRecord]

    private let editingRule: AutomationRuleRecord?

    @State private var name = ""
    @State private var triggerMode = AutomationTriggerMode.device
    @State private var triggerDeviceID = ""
    @State private var triggerSourceID = ""
    @State private var comparison = AutomationComparisonKind.above
    @State private var triggerValue = ""
    @State private var triggerTime = Date()
    @State private var actionDeviceID = ""
    @State private var actionID = ""
    @State private var actionValue = ""
    @State private var isEnabled = true
    @State private var errorMessage: String?

    init(editingRule: AutomationRuleRecord? = nil) {
        self.editingRule = editingRule
        _name = State(initialValue: editingRule?.name ?? "")
        _triggerMode = State(initialValue: editingRule?.triggerMode ?? .device)
        _triggerDeviceID = State(initialValue: editingRule?.triggerDeviceID ?? "")
        _triggerSourceID = State(initialValue: editingRule?.triggerSourceID ?? "")
        _comparison = State(initialValue: AutomationComparisonKind(rawValue: editingRule?.comparison ?? "") ?? .above)
        _triggerValue = State(initialValue: editingRule?.triggerValue ?? "")
        _triggerTime = State(initialValue: Self.date(from: editingRule?.triggerValue) ?? Date())
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
        actionOptions.first(where: { $0.id == actionID })?.payload.type.lowercased() ?? "none"
    }

    private var selectedActionUsesBooleanValue: Bool {
        ["bool", "boolean"].contains(selectedActionPayloadType)
    }

    private var selectedActionRequiresDuration: Bool {
        AutomationActionSupport.timedMotorActionIDs.contains(actionID)
    }

    private var selectedActionStoresValue: Bool {
        selectedActionPayloadType != "none" || selectedActionRequiresDuration
    }

    var body: some View {
        Form {
            Section {
                TextField("Name (optional)", text: $name)
                Toggle("Enabled", isOn: $isEnabled)
            }

            Section("Trigger") {
                Picker("Type", selection: $triggerMode) {
                    ForEach(AutomationTriggerMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch triggerMode {
                case .device:
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
                case .time:
                    DatePicker(
                        "Time",
                        selection: $triggerTime,
                        displayedComponents: .hourAndMinute
                    )
                }
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

                if selectedActionUsesBooleanValue {
                    Picker("Value", selection: $actionValue) {
                        Text("Select state").tag("")
                        Text("Off").tag("false")
                        Text("On").tag("true")
                    }
                } else if selectedActionPayloadType != "none" {
                    TextField("Action value", text: $actionValue)
                        .keyboardType(.numbersAndPunctuation)
                } else if selectedActionRequiresDuration {
                    TextField("Run time (seconds)", text: $actionValue)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .retroSmartScreenBackground()
        .tint(RetroSmartTheme.accent)
        .navigationTitle(editingRule == nil ? "New Automation" : "Edit Automation")
        .navigationBarTitleDisplayMode(.inline)
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
                triggerSourceID = ""
            }
        }
        .onChange(of: triggerMode) { _, newValue in
            if newValue == .time {
                comparison = .equals
            }
        }
        .onChange(of: actionDeviceID) { _, _ in
            if !actionOptions.contains(where: { $0.id == actionID }) {
                actionID = ""
            }
            normalizeActionValueForSelection()
        }
        .onChange(of: actionID) { _, _ in
            normalizeActionValueForSelection()
        }
        .alert("Unable to Save Automation", isPresented: errorAlertIsPresented) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        triggerIsComplete &&
            !actionDeviceID.isEmpty &&
            !actionID.isEmpty
            && actionRequirementsAreComplete
    }

    private var triggerIsComplete: Bool {
        switch triggerMode {
        case .device:
            return !triggerDeviceID.isEmpty &&
                !triggerSourceID.isEmpty &&
                !triggerValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .time:
            return true
        }
    }

    private var actionRequirementsAreComplete: Bool {
        guard selectedActionStoresValue else {
            return true
        }

        let trimmed = actionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if selectedActionUsesBooleanValue {
            return trimmed.lowercased() == "true" || trimmed.lowercased() == "false"
        }

        if selectedActionRequiresDuration {
            guard let duration = Double(trimmed) else {
                return false
            }
            return duration > 0
        }

        switch selectedActionPayloadType {
        case "int", "integer":
            return Int(trimmed) != nil
        case "float", "double", "number", "decimal":
            return Double(trimmed) != nil
        default:
            return true
        }
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
        let resolvedName = trimmedName.isEmpty ? generatedName : trimmedName
        let storedTriggerDeviceID = storedTriggerDeviceID()
        let storedTriggerSourceID = storedTriggerSourceID()
        let storedComparison = storedComparison()
        let storedTriggerValue = storedTriggerValue()
        let storedActionValue = storedActionValue()

        if let editingRule {
            editingRule.name = resolvedName
            editingRule.isEnabled = isEnabled
            editingRule.triggerDeviceID = storedTriggerDeviceID
            editingRule.triggerSourceID = storedTriggerSourceID
            editingRule.comparison = storedComparison
            editingRule.triggerValue = storedTriggerValue
            editingRule.actionDeviceID = actionDeviceID
            editingRule.actionID = actionID
            editingRule.actionValue = storedActionValue
        } else {
            modelContext.insert(
                AutomationRuleRecord(
                    name: resolvedName,
                    isEnabled: isEnabled,
                    triggerDeviceID: storedTriggerDeviceID,
                    triggerSourceID: storedTriggerSourceID,
                    comparison: storedComparison,
                    triggerValue: storedTriggerValue,
                    actionDeviceID: actionDeviceID,
                    actionID: actionID,
                    actionValue: storedActionValue
                )
            )
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var generatedName: String {
        let triggerDeviceName: String? = switch triggerMode {
        case .device:
            devices.first(where: { $0.deviceID == triggerDeviceID })?.customName
        case .time:
            "At \(Self.displayTimeString(from: triggerTime))"
        }
        let actionDeviceName = devices.first(where: { $0.deviceID == actionDeviceID })?.customName

        switch (triggerDeviceName, actionDeviceName) {
        case let (.some(trigger), .some(action)):
            return "\(trigger) -> \(action)"
        case let (.some(trigger), nil):
            return trigger
        case let (nil, .some(action)):
            return action
        case (nil, nil):
            return "Automation"
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

    private func storedTriggerDeviceID() -> String {
        switch triggerMode {
        case .device:
            return triggerDeviceID
        case .time:
            return AutomationSpecialTrigger.timeDeviceID
        }
    }

    private func storedTriggerSourceID() -> String {
        switch triggerMode {
        case .device:
            return triggerSourceID
        case .time:
            return AutomationSpecialTrigger.timeSourceID
        }
    }

    private func storedComparison() -> String {
        switch triggerMode {
        case .device:
            comparison.rawValue
        case .time:
            AutomationComparisonKind.equals.rawValue
        }
    }

    private func storedTriggerValue() -> String {
        switch triggerMode {
        case .device:
            triggerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        case .time:
            Self.storedTimeString(from: triggerTime)
        }
    }

    private func storedActionValue() -> String? {
        guard selectedActionStoresValue else {
            return nil
        }

        let trimmed = actionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizeActionValueForSelection() {
        let trimmed = actionValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !selectedActionStoresValue {
            actionValue = ""
            return
        }

        if selectedActionUsesBooleanValue,
           trimmed.lowercased() != "true",
           trimmed.lowercased() != "false" {
            actionValue = ""
            return
        }

        if selectedActionRequiresDuration, !trimmed.isEmpty, Double(trimmed) == nil {
            actionValue = ""
        }
    }

    private static func date(from storedTime: String?) -> Date? {
        guard let storedTime else {
            return nil
        }

        let components = storedTime.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = hour
        dateComponents.minute = minute
        return Calendar.current.date(from: dateComponents)
    }

    private static func storedTimeString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func displayTimeString(from date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
