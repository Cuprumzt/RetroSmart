import Foundation

@MainActor
final class AutomationEngine {
    private weak var bleManager: RetroSmartBLEManager?
    private weak var configRegistry: ModuleConfigRegistry?
    private var rules: [AutomationRuleRecord] = []
    private var devicesByID: [String: DeviceRecord] = [:]
    private var isForegroundActive = false
    private var lastExecutionDates: [UUID: Date] = [:]
    private var lastTriggerMatches: [UUID: Bool] = [:]
    private var evaluationTimer: Timer?
    private var pendingStopTasks: [UUID: Task<Void, Never>] = [:]
    private let minimumExecutionInterval: TimeInterval = 2
    private let timeTriggerCheckInterval: TimeInterval = 15

    func configure(bleManager: RetroSmartBLEManager, configRegistry: ModuleConfigRegistry) {
        self.bleManager = bleManager
        self.configRegistry = configRegistry
    }

    func sync(devices: [DeviceRecord], automations: [AutomationRuleRecord]) {
        devicesByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceID, $0) })
        rules = automations
        let activeRuleIDs = Set(automations.map(\.id))
        lastExecutionDates = lastExecutionDates.filter { activeRuleIDs.contains($0.key) }
        lastTriggerMatches = lastTriggerMatches.filter { activeRuleIDs.contains($0.key) }
        evaluateIfNeeded()
    }

    func setForegroundActive(_ active: Bool) {
        isForegroundActive = active
        configureEvaluationTimer(active: active)
        evaluateIfNeeded()
    }

    func executeManually(rule: AutomationRuleRecord) {
        let now = Date()
        execute(rule: rule)
        lastExecutionDates[rule.id] = now
        rule.lastTriggeredAt = now
    }

    func evaluateIfNeeded() {
        guard isForegroundActive, let bleManager else {
            return
        }

        let now = Date()

        for rule in rules where rule.isEnabled {
            let doesMatch: Bool
            switch rule.triggerMode {
            case .device:
                guard let triggerState = bleManager.liveStates[rule.triggerDeviceID] else {
                    lastTriggerMatches[rule.id] = false
                    continue
                }
                guard let value = triggerState.values[rule.triggerSourceID] else {
                    lastTriggerMatches[rule.id] = false
                    continue
                }

                doesMatch = doesTrigger(rule: rule, on: value)
            case .time:
                doesMatch = doesTimeTrigger(rule: rule, now: now)
            }

            let matchedPreviously = lastTriggerMatches[rule.id] ?? false
            lastTriggerMatches[rule.id] = doesMatch

            guard doesMatch else {
                continue
            }
            guard !matchedPreviously else {
                continue
            }

            if let lastExecution = lastExecutionDates[rule.id], now.timeIntervalSince(lastExecution) < minimumExecutionInterval {
                continue
            }

            execute(rule: rule)
            lastExecutionDates[rule.id] = now
            rule.lastTriggeredAt = now
        }

        for rule in rules where !rule.isEnabled {
            lastTriggerMatches[rule.id] = false
        }
    }

    private func doesTrigger(rule: AutomationRuleRecord, on value: JSONValue) -> Bool {
        let comparison = AutomationComparisonKind(rawValue: rule.comparison) ?? .equals

        switch comparison {
        case .above:
            guard let current = value.doubleValue, let target = Double(rule.triggerValue) else {
                return false
            }
            return current > target
        case .below:
            guard let current = value.doubleValue, let target = Double(rule.triggerValue) else {
                return false
            }
            return current < target
        case .equals:
            if let current = value.doubleValue, let target = Double(rule.triggerValue) {
                return abs(current - target) < 0.0001
            }
            return value.stringValue.localizedCaseInsensitiveCompare(rule.triggerValue) == .orderedSame
        }
    }

    private func execute(rule: AutomationRuleRecord) {
        guard let bleManager else {
            return
        }

        if rule.actionID == AutomationActionSupport.timedMotorStopActionID {
            cancelPendingStop(for: rule.id)
        }

        bleManager.sendCommand(
            to: rule.actionDeviceID,
            actionID: rule.actionID,
            payload: payload(for: rule)
        )

        if let duration = timedMotorDuration(for: rule) {
            scheduleTimedMotorStop(for: rule, after: duration)
        }
    }

    private func payload(for rule: AutomationRuleRecord) -> [String: JSONValue] {
        guard let rawActionValue = rule.actionValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawActionValue.isEmpty else {
            return [:]
        }

        if let payloadType = declaredPayloadType(for: rule) {
            if payloadType == "none" {
                return [:]
            }

            if let typedValue = parseActionValue(rawActionValue, payloadType: payloadType) {
                return ["value": typedValue]
            }
        }

        return ["value": inferActionValue(rawActionValue)]
    }

    private func declaredPayloadType(for rule: AutomationRuleRecord) -> String? {
        guard let configRegistry,
              let actionDevice = devicesByID[rule.actionDeviceID],
              let moduleConfig = configRegistry.config(for: actionDevice.assignedTypeID)?.config,
              let action = moduleConfig.capabilities.actions.first(where: { $0.id == rule.actionID }) else {
            return nil
        }

        return action.payload.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func parseActionValue(_ rawValue: String, payloadType: String) -> JSONValue? {
        switch payloadType {
        case "bool", "boolean":
            guard let boolValue = parseBooleanString(rawValue) else {
                return nil
            }
            return .bool(boolValue)
        case "int", "integer":
            guard let intValue = Int(rawValue) else {
                return nil
            }
            return .int(intValue)
        case "float", "double", "number", "decimal":
            guard let doubleValue = Double(rawValue) else {
                return nil
            }
            return .double(doubleValue)
        case "string", "text", "enum":
            return .string(rawValue)
        default:
            return nil
        }
    }

    private func inferActionValue(_ rawValue: String) -> JSONValue {
        if let intValue = Int(rawValue) {
            return .int(intValue)
        }
        if let doubleValue = Double(rawValue) {
            return .double(doubleValue)
        }
        if let boolValue = parseBooleanString(rawValue) {
            return .bool(boolValue)
        }

        return .string(rawValue)
    }

    private func parseBooleanString(_ rawValue: String) -> Bool? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "on", "1":
            return true
        case "false", "no", "off", "0":
            return false
        default:
            return nil
        }
    }

    private func doesTimeTrigger(rule: AutomationRuleRecord, now: Date) -> Bool {
        guard let targetTime = parseHourMinute(rule.triggerValue) else {
            return false
        }

        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        return currentComponents.hour == targetTime.hour && currentComponents.minute == targetTime.minute
    }

    private func parseHourMinute(_ value: String) -> (hour: Int, minute: Int)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              (0 ... 23).contains(hour),
              (0 ... 59).contains(minute) else {
            return nil
        }

        return (hour, minute)
    }

    private func configureEvaluationTimer(active: Bool) {
        evaluationTimer?.invalidate()
        evaluationTimer = nil

        guard active else {
            return
        }

        evaluationTimer = Timer.scheduledTimer(withTimeInterval: timeTriggerCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateIfNeeded()
            }
        }
    }

    private func timedMotorDuration(for rule: AutomationRuleRecord) -> TimeInterval? {
        guard AutomationActionSupport.timedMotorActionIDs.contains(rule.actionID),
              let rawDuration = rule.actionValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              let duration = Double(rawDuration),
              duration > 0 else {
            return nil
        }

        return duration
    }

    private func scheduleTimedMotorStop(for rule: AutomationRuleRecord, after duration: TimeInterval) {
        cancelPendingStop(for: rule.id)

        pendingStopTasks[rule.id] = Task { [weak self] in
            let delay = UInt64(duration * 1_000_000_000)

            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            await MainActor.run {
                self?.sendTimedMotorStop(for: rule)
            }
        }
    }

    private func cancelPendingStop(for ruleID: UUID) {
        pendingStopTasks[ruleID]?.cancel()
        pendingStopTasks[ruleID] = nil
    }

    private func sendTimedMotorStop(for rule: AutomationRuleRecord) {
        pendingStopTasks[rule.id] = nil
        bleManager?.sendCommand(
            to: rule.actionDeviceID,
            actionID: AutomationActionSupport.timedMotorStopActionID,
            payload: [:]
        )
    }

    deinit {
        evaluationTimer?.invalidate()
        pendingStopTasks.values.forEach { $0.cancel() }
    }
}
