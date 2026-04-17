import SwiftData
import SwiftUI

struct DeviceOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: [SortDescriptor(\DeviceRecord.insertionIndex, order: .forward)]) private var devices: [DeviceRecord]

    let onSave: () -> Void

    @State private var customName: String
    @State private var iconSystemName: String
    @State private var assignedTypeID: String
    @State private var showingTechnicalDetails = false
    @State private var errorMessage: String?

    let draft: DeviceOnboardingDraft

    init(draft: DeviceOnboardingDraft, onSave: @escaping () -> Void) {
        self.draft = draft
        self.onSave = onSave
        _customName = State(initialValue: draft.customName)
        _iconSystemName = State(initialValue: draft.iconSystemName)
        _assignedTypeID = State(initialValue: draft.assignedTypeID)
    }

    var body: some View {
        Form {
            Section {
                DeviceOnboardingSummaryCard(
                    customName: customName,
                    iconSystemName: iconSystemName,
                    advertisedTypeID: draft.advertisedTypeID
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if assignedTypeID != draft.advertisedTypeID {
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
                TextField("Name", text: $customName)

                Picker("Module Type", selection: $assignedTypeID) {
                    ForEach(appModel.configRegistry.loadedConfigs) { loadedConfig in
                        Text(loadedConfig.config.module.displayName)
                            .tag(loadedConfig.config.module.typeID)
                    }
                }
            }

            Section("Icon") {
                IconPickerView(
                    selectedSymbol: $iconSystemName,
                    suggestions: appModel.configRegistry.config(for: assignedTypeID)?.config.ui.iconSuggestions ?? []
                )
                .padding(.vertical, 8)
            }

            Section("Inspect") {
                DisclosureGroup("Details", isExpanded: $showingTechnicalDetails) {
                    LabeledContent("Device ID", value: draft.deviceID)
                    LabeledContent("Advertised Type", value: draft.advertisedTypeID)
                    LabeledContent("Firmware", value: draft.firmwareVersion)
                }
                .tint(.primary)
            }
        }
        .scrollContentBackground(.hidden)
        .retroSmartScreenBackground()
        .tint(RetroSmartTheme.accent)
        .navigationTitle("Confirm Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveDevice()
                }
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.configRegistry.config(for: assignedTypeID) == nil)
            }
        }
        .alert("Unable to Save Device", isPresented: errorAlertIsPresented) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveDevice() {
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextIndex = (devices.map(\.insertionIndex).max() ?? -1) + 1
        let record: DeviceRecord

        if let existing = devices.first(where: { $0.deviceID == draft.deviceID }) {
            existing.customName = trimmedName
            existing.iconSystemName = iconSystemName
            existing.assignedTypeID = assignedTypeID
            existing.advertisedTypeID = draft.advertisedTypeID
            existing.modelName = draft.modelName
            existing.firmwareVersion = draft.firmwareVersion
            existing.peripheralIdentifier = draft.peripheralIdentifier.uuidString
            record = existing
        } else {
            let newRecord = DeviceRecord(
                deviceID: draft.deviceID,
                customName: trimmedName,
                iconSystemName: iconSystemName,
                assignedTypeID: assignedTypeID,
                advertisedTypeID: draft.advertisedTypeID,
                modelName: draft.modelName,
                firmwareVersion: draft.firmwareVersion,
                peripheralIdentifier: draft.peripheralIdentifier.uuidString,
                insertionIndex: nextIndex
            )
            modelContext.insert(newRecord)
            record = newRecord
        }

        do {
            try modelContext.save()
            appModel.bleManager.markDeviceAdded(
                deviceID: record.deviceID,
                peripheralIdentifier: draft.peripheralIdentifier
            )
            onSave()
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

private struct DeviceOnboardingSummaryCard: View {
    let customName: String
    let iconSystemName: String
    let advertisedTypeID: String

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

            RetroSmartTag(title: "Nearby", systemImage: "dot.radiowaves.left.and.right", tone: .accent)
        }
        .padding(20)
        .retroSmartSurface(tone: .accent)
    }
}
