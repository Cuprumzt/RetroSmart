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

                    LabeledContent("Module Type", value: typeLabel)
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
    @State private var sliderCommitTasks: [String: Task<Void, Never>] = [:]
    @State private var toggleValues: [String: Bool] = [:]

    private var isDeviceOnline: Bool {
        appModel.bleManager.connectionStates[device.deviceID] == .connected
    }

    @ViewBuilder
    var body: some View {
        if config.ui.devicePage.layout == "motor_directional" {
            motorDirectionalLayout
        } else {
            standardWidgetLayout
        }
    }

    private var standardWidgetLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(config.ui.devicePage.widgets) { widget in
                widgetView(for: widget)
            }
        }
    }

    private var motorDirectionalLayout: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                directionalMotorButton(
                    for: motorReverseWidget,
                    fallbackTitle: "Reverse",
                    systemImage: "arrow.left"
                )

                directionalMotorButton(
                    for: motorForwardWidget,
                    fallbackTitle: "Forward",
                    systemImage: "arrow.right"
                )
            }

            if let motorStateWidget {
                VStack(spacing: 6) {
                    Text(motorStateWidget.label ?? "Motor State")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    let statePresentation = motorStatePresentation(for: motorStateWidget)

                    Label {
                        Text(statePresentation.title)
                            .font(.title3.weight(.semibold))
                    } icon: {
                        Image(systemName: statePresentation.systemImage)
                            .font(.headline.weight(.semibold))
                    }
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(statePresentation.tint)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }

            ForEach(remainingMotorWidgets) { widget in
                widgetView(for: widget)
            }
        }
    }

    private var motorForwardWidget: WidgetConfig? {
        config.ui.devicePage.widgets.first { $0.id == "motor_forward" }
    }

    private var motorReverseWidget: WidgetConfig? {
        config.ui.devicePage.widgets.first { $0.id == "motor_reverse" }
    }

    private var motorStateWidget: WidgetConfig? {
        config.ui.devicePage.widgets.first { $0.id == "motor_state" }
    }

    private var remainingMotorWidgets: [WidgetConfig] {
        config.ui.devicePage.widgets.filter { widget in
            !["motor_forward", "motor_reverse", "motor_state"].contains(widget.id)
        }
    }

    private func widgetView(for widget: WidgetConfig) -> AnyView {
        guard isWidgetVisible(widget) else {
            return AnyView(EmptyView())
        }

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
                .disabled(!isDeviceOnline)
            )
        case .holdButton:
            return AnyView(
                HoldActionButton(
                    title: widget.label ?? "Hold",
                    systemImage: nil,
                    tint: .accentColor,
                    onPress: {
                        send(actionID: widget.action, value: nil)
                    },
                    onRelease: {
                        send(actionID: widget.releaseAction, value: nil)
                    }
                )
                .disabled(!isDeviceOnline)
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
                            }
                        ),
                        in: range,
                        onEditingChanged: { isEditing in
                            if isEditing {
                                scheduleSliderCommit(for: widget, delayNanoseconds: 60_000_000)
                            } else {
                                commitSliderValue(for: widget)
                            }
                        }
                    )
                    .onChange(of: sliderValues[widget.id] ?? sliderValue(for: widget)) { _, _ in
                        scheduleSliderCommit(for: widget, delayNanoseconds: 60_000_000)
                    }
                    .disabled(!isDeviceOnline)
                }
            )
        case .reading:
            if widget.id == "servo_angle_readback" {
                let positionPresentation = servoPositionPresentation(for: widget)

                return AnyView(
                    VStack(spacing: 8) {
                        Label {
                            Text(widget.label ?? widget.source ?? "Reading")
                                .font(.headline)
                        } icon: {
                            Image(systemName: positionPresentation.systemImage)
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(positionPresentation.tint)

                        Text(positionPresentation.valueText)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(positionPresentation.tint)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                )
            }

            return AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    Text(widget.label ?? widget.source ?? "Reading")
                        .font(.headline)
                    Text(displayValue(for: widget))
                        .font(.title3.weight(.semibold))
                }
                .padding(.vertical, 4)
            )
        case .toggle:
            return AnyView(
                Toggle(isOn: Binding(
                    get: { toggleValue(for: widget) },
                    set: { newValue in
                        toggleValues[widget.id] = newValue
                        send(actionID: widget.action, value: .bool(newValue))
                    }
                )) {
                    Text(widget.label ?? "Toggle")
                }
                .disabled(!isDeviceOnline)
            )
        }
    }

    private func directionalMotorButton(
        for widget: WidgetConfig?,
        fallbackTitle: String,
        systemImage: String
    ) -> AnyView {
        guard let widget else {
            return AnyView(
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 96)
            )
        }

        let title = widget.label ?? fallbackTitle
        let isEnabled = isDeviceOnline

        return AnyView(
            HoldActionButton(
                title: title,
                systemImage: systemImage,
                tint: .accentColor,
                onPress: {
                    send(actionID: widget.action, value: nil)
                },
                onRelease: {
                    send(actionID: widget.releaseAction, value: nil)
                }
            )
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        )
    }

    private func motorStatePresentation(for widget: WidgetConfig) -> (title: String, systemImage: String, tint: Color) {
        guard let source = widget.source, let value = liveState?.values[source]?.stringValue else {
            return ("No Data Yet", "questionmark.circle", .secondary)
        }

        switch value {
        case "forward":
            return ("Forward", "arrow.right.circle.fill", .accentColor)
        case "reverse":
            return ("Reverse", "arrow.left.circle.fill", .accentColor)
        case "stopped":
            return ("Stopped", "pause.circle.fill", .secondary)
        default:
            return (value.replacingOccurrences(of: "_", with: " ").capitalized, "gearshape.2.fill", .secondary)
        }
    }

    private func servoPositionPresentation(for widget: WidgetConfig) -> (valueText: String, systemImage: String, tint: Color) {
        guard let source = widget.source, let currentAngle = liveState?.values[source]?.doubleValue else {
            return ("No data yet", "questionmark.circle", .secondary)
        }

        let targetAngle = sliderValues["servo_angle"] ?? currentAngle
        let isMoving = abs(targetAngle - currentAngle) >= 1
        let valueText = "\(Int(currentAngle.rounded()))°"

        if isMoving {
            return (valueText, "arrow.triangle.2.circlepath.circle.fill", .accentColor)
        }

        return (valueText, "checkmark.circle.fill", .secondary)
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

    private func toggleValue(for widget: WidgetConfig) -> Bool {
        if let toggleValue = toggleValues[widget.id] {
            return toggleValue
        }
        if let source = widget.source, let currentValue = liveState?.values[source]?.boolValue {
            return currentValue
        }
        return false
    }

    private func displayValue(for widget: WidgetConfig) -> String {
        guard let source = widget.source, let value = liveState?.values[source] else {
            return "No data yet"
        }

        let unitSuffix = widget.unit.map { " \($0)" } ?? ""
        return value.stringValue + unitSuffix
    }

    private func isWidgetVisible(_ widget: WidgetConfig) -> Bool {
        guard let visibleWhenSource = widget.visibleWhenSource else {
            return true
        }

        guard let currentValue = liveState?.values[visibleWhenSource]?.stringValue else {
            return false
        }

        guard let visibleWhenEquals = widget.visibleWhenEquals else {
            return true
        }

        return currentValue.localizedCaseInsensitiveCompare(visibleWhenEquals) == .orderedSame
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

    private func scheduleSliderCommit(for widget: WidgetConfig, delayNanoseconds: UInt64) {
        sliderCommitTasks[widget.id]?.cancel()
        sliderCommitTasks[widget.id] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            commitSliderValue(for: widget)
        }
    }

    private func commitSliderValue(for widget: WidgetConfig) {
        sliderCommitTasks[widget.id]?.cancel()
        sliderCommitTasks[widget.id] = nil
        let value = Int(sliderValue(for: widget).rounded())
        send(actionID: widget.action, value: .int(value))
    }
}
