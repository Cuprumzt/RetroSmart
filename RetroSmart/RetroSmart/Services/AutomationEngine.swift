import Foundation

@MainActor
final class AutomationEngine {
    private weak var bleManager: RetroSmartBLEManager?
    private var rules: [AutomationRuleRecord] = []
    private var isForegroundActive = false
    private var lastExecutionDates: [UUID: Date] = [:]
    private var lastTriggerMatches: [UUID: Bool] = [:]
    private let minimumExecutionInterval: TimeInterval = 2

    func configure(bleManager: RetroSmartBLEManager, configRegistry _: ModuleConfigRegistry) {
        self.bleManager = bleManager
    }

    func sync(devices _: [DeviceRecord], automations: [AutomationRuleRecord]) {
        rules = automations
        let activeRuleIDs = Set(automations.map(\.id))
        lastExecutionDates = lastExecutionDates.filter { activeRuleIDs.contains($0.key) }
        lastTriggerMatches = lastTriggerMatches.filter { activeRuleIDs.contains($0.key) }
        evaluateIfNeeded()
    }

    func setForegroundActive(_ active: Bool) {
        isForegroundActive = active
        evaluateIfNeeded()
    }

    func evaluateIfNeeded() {
        guard isForegroundActive, let bleManager else {
            return
        }

        let now = Date()

        for rule in rules where rule.isEnabled {
            guard let triggerState = bleManager.liveStates[rule.triggerDeviceID] else {
                lastTriggerMatches[rule.id] = false
                continue
            }
            guard let value = triggerState.values[rule.triggerSourceID] else {
                lastTriggerMatches[rule.id] = false
                continue
            }

            let doesMatch = doesTrigger(rule: rule, on: value)
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

        let payload: [String: JSONValue]
        if let actionValue = rule.actionValue, !actionValue.isEmpty {
            if let intValue = Int(actionValue) {
                payload = ["value": .int(intValue)]
            } else if let doubleValue = Double(actionValue) {
                payload = ["value": .double(doubleValue)]
            } else {
                payload = ["value": .string(actionValue)]
            }
        } else {
            payload = [:]
        }

        bleManager.sendCommand(
            to: rule.actionDeviceID,
            actionID: rule.actionID,
            payload: payload
        )
    }
}
