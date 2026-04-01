import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let configRegistry = ModuleConfigRegistry()
    let bleManager = RetroSmartBLEManager()
    let automationEngine = AutomationEngine()

    private var cancellables: Set<AnyCancellable> = []

    init() {
        bleManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        configRegistry.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        bleManager.$liveStates
            .sink { [weak self] _ in
                self?.automationEngine.evaluateIfNeeded()
            }
            .store(in: &cancellables)

        bleManager.$connectionStates
            .sink { [weak self] _ in
                self?.automationEngine.evaluateIfNeeded()
            }
            .store(in: &cancellables)

        automationEngine.configure(
            bleManager: bleManager,
            configRegistry: configRegistry
        )
    }

    func sync(
        devices: [DeviceRecord],
        importedConfigs: [ImportedDeviceTypeRecord],
        automations: [AutomationRuleRecord]
    ) {
        configRegistry.reload(importedConfigs: importedConfigs)
        bleManager.syncKnownDevices(devices)
        automationEngine.sync(devices: devices, automations: automations)
    }

    func setForegroundActive(_ isActive: Bool) {
        bleManager.setForegroundActive(isActive)
        automationEngine.setForegroundActive(isActive)
    }
}
