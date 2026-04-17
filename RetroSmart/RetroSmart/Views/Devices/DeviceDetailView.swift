import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var appModel: AppModel

    let device: DeviceRecord

    @State private var showingSettings = false
    @State private var showingTechnicalDetails = false

    private var assignedConfig: LoadedModuleConfig? {
        appModel.configRegistry.config(for: device.assignedTypeID)
    }

    private var connectionState: DeviceConnectionState {
        appModel.bleManager.connectionStates[device.deviceID] ?? .disconnected
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DeviceHeaderCard(
                    device: device,
                    typeLabel: typeLabel,
                    connectionState: connectionState,
                    lastUpdate: liveState?.lastUpdate,
                    showsSecondaryLabel: showsSecondaryLabel
                )

                if let assignedConfig {
                    RetroSmartSectionHeader(
                        eyebrow: "Controls",
                        title: "Controls & readings"
                    )

                    DeviceWidgetRenderer(
                        device: device,
                        config: assignedConfig.config,
                        liveState: liveState
                    )
                } else {
                    RetroSmartEmptyStateCard(
                        title: "Module type unavailable",
                        message: "Re-import it or choose another type.",
                        systemImage: "exclamationmark.triangle.fill",
                        tone: .warning
                    )
                }

                RetroSmartSectionHeader(
                    eyebrow: "Inspect",
                    title: "Technical details"
                )

                DeviceTechnicalDetailsCard(
                    device: device,
                    typeLabel: typeLabel,
                    liveState: liveState,
                    isExpanded: $showingTechnicalDetails
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .retroSmartScreenBackground()
        .navigationTitle(device.customName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(RetroSmartTheme.accent.opacity(0.14))
                        .foregroundStyle(RetroSmartTheme.accentStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

private struct DeviceHeaderCard: View {
    let device: DeviceRecord
    let typeLabel: String
    let connectionState: DeviceConnectionState
    let lastUpdate: Date?
    let showsSecondaryLabel: Bool

    private var tone: RetroSmartSurfaceTone {
        switch connectionState {
        case .connected:
            return .accent
        case .connecting:
            return .warning
        case .disconnected:
            return .neutral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: device.iconSystemName)
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .background(RetroSmartTheme.accent.opacity(0.14))
                    .foregroundStyle(RetroSmartTheme.accentStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.customName)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.rounded)

                    if showsSecondaryLabel {
                        Text(typeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                StatusBadge(state: connectionState, style: .deviceDetail)
                    .layoutPriority(1)
            }

            if let lastUpdate {
                RetroSmartTag(
                    title: "Updated \(lastUpdate.formatted(date: .omitted, time: .shortened))",
                    systemImage: "clock",
                    tone: .subdued
                )
            }
        }
        .padding(22)
        .retroSmartSurface(tone: tone)
    }
}

private struct DeviceTechnicalDetailsCard: View {
    let device: DeviceRecord
    let typeLabel: String
    let liveState: LiveDeviceState?
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup("Show details", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if device.assignedTypeID != device.advertisedTypeID {
                    Label("Assigned type differs from the module’s advertised type.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(RetroSmartTheme.warning)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .retroSmartSurface(tone: .warning, cornerRadius: 18, shadow: false)
                }

                LabeledContent("Device ID", value: device.deviceID)
                LabeledContent("Module Type", value: typeLabel)
                LabeledContent("Advertised Type", value: device.advertisedTypeID)
                LabeledContent("Firmware", value: device.firmwareVersion)

                if let lastUpdate = liveState?.lastUpdate {
                    LabeledContent("Last Update", value: lastUpdate.formatted(date: .numeric, time: .shortened))
                }

                if let capabilitySummary = liveState?.lastCapabilitySummary, !capabilitySummary.actions.isEmpty {
                    LabeledContent("Actions", value: capabilitySummary.actions.joined(separator: ", "))
                }
            }
            .padding(.top, 12)
        }
        .tint(.primary)
        .padding(20)
        .retroSmartSurface()
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
        VStack(spacing: 16) {
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
                motorStateCard(for: motorStateWidget)
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
                VStack(alignment: .leading, spacing: 12) {
                    if let label = widget.label {
                        Text(label)
                            .font(.headline)
                            .fontDesign(.rounded)
                    }

                    ForEach(widget.widgets) { child in
                        widgetView(for: child)
                    }
                }
                .padding(18)
                .retroSmartSurface()
            )
        case .text:
            return AnyView(
                Text(widget.text ?? widget.label ?? "")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .retroSmartSurface(tone: .subdued, cornerRadius: 20, shadow: false)
            )
        case .status:
            return AnyView(
                HStack {
                    Text(widget.label ?? "Status")
                        .font(.headline)
                        .fontDesign(.rounded)
                    Spacer()
                    StatusBadge(
                        state: appModel.bleManager.connectionStates[device.deviceID] ?? .disconnected,
                        style: .deviceDetail
                    )
                }
                .padding(18)
                .retroSmartSurface()
            )
        case .button:
            return AnyView(
                Button(widget.label ?? widget.action ?? "Run") {
                    send(actionID: widget.action, value: nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(RetroSmartTheme.accent)
                .controlSize(.large)
                .disabled(!isDeviceOnline)
            )
        case .holdButton:
            return AnyView(
                HoldActionButton(
                    title: widget.label ?? "Hold",
                    systemImage: nil,
                    tint: RetroSmartTheme.accent,
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(widget.label ?? "Value")
                            .font(.headline)
                            .fontDesign(.rounded)

                        Spacer()

                        Text(Int(sliderValue(for: widget)).description)
                            .font(.title3.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(RetroSmartTheme.accentStrong)
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
                    .tint(RetroSmartTheme.accent)
                    .onChange(of: sliderValues[widget.id] ?? sliderValue(for: widget)) { _, _ in
                        scheduleSliderCommit(for: widget, delayNanoseconds: 60_000_000)
                    }
                    .disabled(!isDeviceOnline)
                }
                .padding(18)
                .retroSmartSurface(tone: .accent)
            )
        case .reading:
            return AnyView(readingCard(for: widget))
        case .toggle:
            return AnyView(
                Toggle(isOn: Binding(
                    get: { toggleValue(for: widget) },
                    set: { newValue in
                        toggleValues[widget.id] = newValue
                        send(actionID: widget.action, value: .bool(newValue))
                    }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(widget.label ?? "Toggle")
                            .font(.headline)
                            .fontDesign(.rounded)
                    }
                }
                .tint(RetroSmartTheme.accent)
                .disabled(!isDeviceOnline)
                .padding(18)
                .retroSmartSurface()
            )
        }
    }

    private func readingCard(for widget: WidgetConfig) -> some View {
        let presentation = readingPresentation(for: widget)

        return VStack(alignment: .leading, spacing: 12) {
            Label(widget.label ?? widget.source ?? "Reading", systemImage: presentation.systemImage)
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(presentation.labelColor)

            if widget.id == "servo_angle_readback" {
                let servoPresentation = servoPositionPresentation(for: widget)

                Text(servoPresentation.valueText)
                    .font(.title.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(servoPresentation.tint)

                RetroSmartTag(
                    title: servoPresentation.statusText,
                    systemImage: servoPresentation.systemImage,
                    tone: servoPresentation.tone
                )
            } else {
                Text(displayValue(for: widget))
                    .font(presentation.valueFont)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .retroSmartSurface(tone: presentation.tone)
    }

    private func directionalMotorButton(
        for widget: WidgetConfig?,
        fallbackTitle: String,
        systemImage: String
    ) -> some View {
        Group {
            if let widget {
                HoldActionButton(
                    title: widget.label ?? fallbackTitle,
                    systemImage: systemImage,
                    tint: RetroSmartTheme.accent,
                    onPress: {
                        send(actionID: widget.action, value: nil)
                    },
                    onRelease: {
                        send(actionID: widget.releaseAction, value: nil)
                    }
                )
                .disabled(!isDeviceOnline)
                .opacity(isDeviceOnline ? 1 : 0.5)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 112)
            }
        }
    }

    private func motorStateCard(for widget: WidgetConfig) -> some View {
        let statePresentation = motorStatePresentation(for: widget)

        return VStack(spacing: 8) {
            Text(widget.label ?? "Motor State")
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)

            Label(statePresentation.title, systemImage: statePresentation.systemImage)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(statePresentation.tint)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .retroSmartSurface(tone: statePresentation.tone)
    }

    private func motorStatePresentation(for widget: WidgetConfig) -> (title: String, systemImage: String, tint: Color, tone: RetroSmartSurfaceTone) {
        guard let source = widget.source, let value = liveState?.values[source]?.stringValue else {
            return ("No Data Yet", "questionmark.circle", RetroSmartTheme.quiet, .subdued)
        }

        switch value {
        case "forward":
            return ("Forward", "arrow.right.circle.fill", RetroSmartTheme.accentStrong, .accent)
        case "reverse":
            return ("Reverse", "arrow.left.circle.fill", RetroSmartTheme.accentStrong, .accent)
        case "stopped":
            return ("Stopped", "pause.circle.fill", RetroSmartTheme.quiet, .neutral)
        default:
            return (value.replacingOccurrences(of: "_", with: " ").capitalized, "gearshape.2.fill", RetroSmartTheme.quiet, .neutral)
        }
    }

    private func servoPositionPresentation(for widget: WidgetConfig) -> (valueText: String, statusText: String, systemImage: String, tint: Color, tone: RetroSmartSurfaceTone) {
        guard let source = widget.source, let currentAngle = liveState?.values[source]?.doubleValue else {
            return ("No data yet", "Waiting for device state", "questionmark.circle", RetroSmartTheme.quiet, .subdued)
        }

        let targetAngle = sliderValues["servo_angle"] ?? currentAngle
        let isMoving = abs(targetAngle - currentAngle) >= 1
        let valueText = "\(Int(currentAngle.rounded()))°"

        if isMoving {
            return (valueText, "Servo moving", "arrow.triangle.2.circlepath.circle.fill", RetroSmartTheme.accentStrong, .accent)
        }

        return (valueText, "Position reached", "checkmark.circle.fill", RetroSmartTheme.quiet, .neutral)
    }

    private func readingPresentation(for widget: WidgetConfig) -> (systemImage: String, tone: RetroSmartSurfaceTone, labelColor: Color, valueFont: Font) {
        let identifier = [widget.id, widget.source, widget.label]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if identifier.contains("temperature") {
            return ("thermometer.medium", .accent, RetroSmartTheme.accentStrong, .title.weight(.semibold))
        }

        if identifier.contains("quality_score") || identifier.contains("air quality") {
            return ("aqi.medium", .accent, RetroSmartTheme.accentStrong, .largeTitle.weight(.semibold))
        }

        if identifier.contains("voc") {
            return ("wind", .neutral, .primary, .title2.weight(.semibold))
        }

        return ("gauge.with.needle", .neutral, .primary, .title2.weight(.semibold))
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
