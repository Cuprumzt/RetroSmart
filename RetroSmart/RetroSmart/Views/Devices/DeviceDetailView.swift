import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let device: DeviceRecord

    @State private var showingSettings = false
    @State private var showingTechnicalDetails = false

    private var assignedConfig: LoadedModuleConfig? {
        appModel.configRegistry.config(for: device.assignedTypeID)
    }

    private var liveState: LiveDeviceState? {
        appModel.bleManager.liveStates[device.deviceID]
    }

    private var typeLabel: String {
        assignedConfig?.config.module.displayName ?? device.assignedTypeID
    }

    private var showsSecondaryLabel: Bool {
        device.customName.caseInsensitiveCompare(typeLabel) != .orderedSame
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: device.iconSystemName)
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        StatusBadge(
                            state: appModel.bleManager.connectionStates[device.deviceID] ?? .disconnected,
                            style: .deviceDetail
                        )
                    }

                    Text(device.customName)
                        .font(.title2.weight(.semibold))
                    if showsSecondaryLabel {
                        Text(typeLabel)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if let assignedConfig {
                Section("Controls & Readings") {
                    DeviceWidgetRenderer(
                        device: device,
                        config: assignedConfig.config,
                        liveState: liveState
                    )
                }
            } else {
                Section {
                    Text("The assigned module type is unavailable. Re-import the type or choose another type in settings.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                DisclosureGroup("Technical Details", isExpanded: $showingTechnicalDetails) {
                    if device.assignedTypeID != device.advertisedTypeID {
                        Label("Assigned type differs from the module’s advertised type.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(.bottom, 8)
                    }

                    LabeledContent("Assigned Type", value: typeLabel)
                    LabeledContent("Advertised Type", value: device.advertisedTypeID)
                    if let lastUpdate = liveState?.lastUpdate {
                        LabeledContent("Last Update", value: lastUpdate.formatted(date: .numeric, time: .shortened))
                    }
                    if let capabilitySummary = liveState?.lastCapabilitySummary, !capabilitySummary.actions.isEmpty {
                        LabeledContent("Actions", value: capabilitySummary.actions.joined(separator: ", "))
                    }
                }
                .tint(.primary)
            }
        }
        .navigationTitle(device.customName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings") {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                DeviceSettingsView(device: device)
            }
        }
    }
}

private struct DeviceWidgetRenderer: View {
    @EnvironmentObject private var appModel: AppModel

    let device: DeviceRecord
    let config: ModuleConfig
    let liveState: LiveDeviceState?

    @State private var sliderValues: [String: Double] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(config.ui.devicePage.widgets) { widget in
                widgetView(for: widget)
            }
        }
    }

    private func widgetView(for widget: WidgetConfig) -> AnyView {
        switch widget.type {
        case .section:
            return AnyView(
                VStack(alignment: .leading, spacing: 10) {
                    if let label = widget.label {
                        Text(label)
                            .font(.headline)
                    }
                    ForEach(widget.widgets) { child in
                        widgetView(for: child)
                    }
                }
            )
        case .text:
            return AnyView(Text(widget.text ?? widget.label ?? ""))
        case .status:
            return AnyView(
                HStack {
                    Text(widget.label ?? "Status")
                    Spacer()
                    StatusBadge(
                        state: appModel.bleManager.connectionStates[device.deviceID] ?? .disconnected,
                        style: .deviceDetail
                    )
                }
            )
        case .button:
            return AnyView(
                Button(widget.label ?? widget.action ?? "Run") {
                    send(actionID: widget.action, value: nil)
                }
                .buttonStyle(.borderedProminent)
            )
        case .holdButton:
            return AnyView(
                HoldActionButton(
                    title: widget.label ?? "Hold",
                    tint: .accentColor,
                    onPress: {
                        send(actionID: widget.action, value: nil)
                    },
                    onRelease: {
                        send(actionID: widget.releaseAction, value: nil)
                    }
                )
            )
        case .slider:
            let range = (widget.min ?? 0)...(widget.max ?? 100)
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(widget.label ?? "Value")
                        Spacer()
                        Text(Int(sliderValue(for: widget)).description)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { sliderValue(for: widget) },
                            set: { newValue in
                                sliderValues[widget.id] = newValue
                                send(actionID: widget.action, value: .int(Int(newValue.rounded())))
                            }
                        ),
                        in: range
                    )
                }
            )
        case .reading:
            return AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    Text(widget.label ?? widget.source ?? "Reading")
                        .font(.headline)
                    Text(displayValue(for: widget))
                        .font(.title3.weight(.semibold))
                }
                .padding(.vertical, 4)
            )
        }
    }

    private func sliderValue(for widget: WidgetConfig) -> Double {
        if let sliderValue = sliderValues[widget.id] {
            return sliderValue
        }
        if let source = widget.source, let currentValue = liveState?.values[source]?.doubleValue {
            return currentValue
        }
        return widget.min ?? 0
    }

    private func displayValue(for widget: WidgetConfig) -> String {
        guard let source = widget.source, let value = liveState?.values[source] else {
            return "No data yet"
        }

        let unitSuffix = widget.unit.map { " \($0)" } ?? ""
        return value.stringValue + unitSuffix
    }

    private func send(actionID: String?, value: JSONValue?) {
        guard let actionID else { return }
        let payload = value.map { ["value": $0] } ?? [:]
        appModel.bleManager.sendCommand(
            to: device.deviceID,
            actionID: actionID,
            payload: payload
        )
    }
}
