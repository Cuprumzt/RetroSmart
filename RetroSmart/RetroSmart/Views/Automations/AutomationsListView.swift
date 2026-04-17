import SwiftData
import SwiftUI

struct AutomationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: [SortDescriptor(\AutomationRuleRecord.createdAt, order: .forward)]) private var automations: [AutomationRuleRecord]
    @Query(sort: [SortDescriptor(\DeviceRecord.insertionIndex, order: .forward)]) private var devices: [DeviceRecord]

    @State private var presentedRule: AutomationRuleRecord?
    @State private var creatingNewRule = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                AutomationsSummaryCard(
                    ruleCount: automations.count,
                    deviceCount: devices.count
                )
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if automations.isEmpty {
                Section {
                    RetroSmartEmptyStateCard(
                        title: "No automations yet",
                        message: "Foreground only.",
                        systemImage: "bolt.badge.automatic",
                        tone: .neutral
                    )
                    .padding(.vertical, 6)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("Rules") {
                    ForEach(automations) { rule in
                        AutomationRowView(
                            rule: rule,
                            devices: devices,
                            configRegistry: appModel.configRegistry,
                            onEdit: {
                                presentedRule = rule
                            },
                            onRun: {
                                appModel.automationEngine.executeManually(rule: rule)
                                do {
                                    try modelContext.save()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        )
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        do {
                            indexSet.map { automations[$0] }.forEach(modelContext.delete)
                            try modelContext.save()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .retroSmartScreenBackground()
        .navigationTitle("Automations")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creatingNewRule = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(RetroSmartTheme.accent.opacity(0.14))
                        .foregroundStyle(RetroSmartTheme.accentStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!hasActionCapableDevice)
            }
        }
        .sheet(item: $presentedRule) { rule in
            NavigationStack {
                AutomationEditorView(editingRule: rule)
            }
        }
        .sheet(isPresented: $creatingNewRule) {
            NavigationStack {
                AutomationEditorView()
            }
        }
        .alert("Automations", isPresented: errorAlertIsPresented) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
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

    private var hasActionCapableDevice: Bool {
        devices.contains(where: deviceSupportsActions)
    }

    private func deviceSupportsActions(_ device: DeviceRecord) -> Bool {
        guard let config = appModel.configRegistry.config(for: device.assignedTypeID)?.config else {
            return false
        }
        return !config.automation.actions.isEmpty
    }
}

private struct AutomationsSummaryCard: View {
    let ruleCount: Int
    let deviceCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Foreground automation")
                    .font(.title3.weight(.semibold))
                    .fontDesign(.rounded)

                Spacer()

                RetroSmartTag(title: "Local", tone: .subdued)
            }

            HStack(spacing: 12) {
                RetroSmartMetricPill(title: "Rules", value: "\(ruleCount)")
                RetroSmartMetricPill(title: "Devices", value: "\(deviceCount)", tone: deviceCount < 2 ? .warning : .subdued)
            }
        }
        .padding(20)
        .retroSmartSurface(tone: .accent)
    }
}

private struct AutomationRowView: View {
    let rule: AutomationRuleRecord
    let devices: [DeviceRecord]
    let configRegistry: ModuleConfigRegistry
    let onEdit: () -> Void
    let onRun: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.headline)
                        .fontDesign(.rounded)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(triggerSummary)
                        Text(actionSummary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if let lastTriggeredAt = rule.lastTriggeredAt {
                    Text("Last triggered \(lastTriggeredAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRun) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38, alignment: .center)
                    .foregroundStyle(runButtonForeground)
                    .background(runButtonBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .retroSmartSurface()
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    private var runButtonBackground: Color {
        rule.isEnabled ? RetroSmartTheme.success.opacity(0.2) : RetroSmartTheme.accent.opacity(0.14)
    }

    private var runButtonForeground: Color {
        rule.isEnabled ? RetroSmartTheme.success : RetroSmartTheme.accentStrong
    }

    private var triggerSummary: String {
        switch rule.triggerMode {
        case .device:
            let triggerName = devices.first(where: { $0.deviceID == rule.triggerDeviceID })?.customName ?? rule.triggerDeviceID
            let readingLabel = readingLabel(for: rule)
            let comparison = AutomationComparisonKind(rawValue: rule.comparison)?.label ?? rule.comparison
            return "\(triggerName) · \(readingLabel) \(comparison.lowercased()) \(rule.triggerValue)"
        case .time:
            return "Time · at \(displayTime(rule.triggerValue))"
        }
    }

    private var actionSummary: String {
        let actionDeviceName = devices.first(where: { $0.deviceID == rule.actionDeviceID })?.customName ?? rule.actionDeviceID
        let actionLabel = actionLabel(for: rule)
        if let valueSummary = actionValueSummary {
            return "\(actionDeviceName) · \(actionLabel) \(valueSummary)"
        }

        return "\(actionDeviceName) · \(actionLabel)"
    }

    private var actionValueSummary: String? {
        if rule.actionValue == "true" {
            return "On"
        }
        if rule.actionValue == "false" {
            return "Off"
        }
        if AutomationActionSupport.timedMotorActionIDs.contains(rule.actionID),
           let duration = Double(rule.actionValue ?? "") {
            return "for \(duration.formatted(.number.precision(.fractionLength(0...1))))s"
        }
        if let rawValue = rule.actionValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawValue.isEmpty {
            return rawValue
        }

        return nil
    }

    private func readingLabel(for rule: AutomationRuleRecord) -> String {
        guard let triggerDevice = devices.first(where: { $0.deviceID == rule.triggerDeviceID }),
              let config = configRegistry.config(for: triggerDevice.assignedTypeID)?.config,
              let reading = config.capabilities.readings.first(where: { $0.id == rule.triggerSourceID }) else {
            return rule.triggerSourceID
        }

        return reading.label
    }

    private func actionLabel(for rule: AutomationRuleRecord) -> String {
        guard let actionDevice = devices.first(where: { $0.deviceID == rule.actionDeviceID }),
              let config = configRegistry.config(for: actionDevice.assignedTypeID)?.config,
              let action = config.capabilities.actions.first(where: { $0.id == rule.actionID }) else {
            return rule.actionID
        }

        return action.label
    }

    private func displayTime(_ storedTime: String) -> String {
        let components = storedTime.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return storedTime
        }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = hour
        dateComponents.minute = minute
        guard let date = Calendar.current.date(from: dateComponents) else {
            return storedTime
        }

        return date.formatted(date: .omitted, time: .shortened)
    }
}
