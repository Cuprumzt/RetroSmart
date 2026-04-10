import CoreBluetooth
import Foundation

struct NearbyPeripheral: Identifiable, Equatable {
    let id: UUID
    let peripheralIdentifier: UUID
    let name: String
    let rssi: Int
}

struct NearbyResolvedDevice {
    let peripheralIdentifier: UUID
    let identity: IdentityPayload
}

private struct KnownDeviceDescriptor {
    let deviceID: String
    let peripheralIdentifier: UUID?
}

private struct PeripheralContext {
    let peripheral: CBPeripheral
    var advertisedName: String?
    var rssi: Int = 0
    var identityCharacteristic: CBCharacteristic?
    var capabilitiesCharacteristic: CBCharacteristic?
    var stateCharacteristic: CBCharacteristic?
    var commandCharacteristic: CBCharacteristic?
    var identityPayload: IdentityPayload?
}

@MainActor
final class RetroSmartBLEManager: NSObject, ObservableObject {
    @Published private(set) var nearbyPeripherals: [NearbyPeripheral] = []
    @Published private(set) var connectionStates: [String: DeviceConnectionState] = [:]
    @Published private(set) var liveStates: [String: LiveDeviceState] = [:]
    @Published var debugMessages: [String] = []
    @Published private(set) var bluetoothState: CBManagerState = .unknown

    private lazy var centralManager = CBCentralManager(delegate: self, queue: nil)
    private var foregroundActive = false
    private var knownDevices: [String: KnownDeviceDescriptor] = [:]
    private var peripheralContexts: [UUID: PeripheralContext] = [:]
    private var pendingIdentityContinuations: [UUID: CheckedContinuation<NearbyResolvedDevice, Error>] = [:]
    private var autoConnectInFlight: Set<UUID> = []
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var bluetoothStateLabel: String {
        bluetoothState.debugLabel
    }

    func setForegroundActive(_ active: Bool) {
        foregroundActive = active
        if active {
            beginScanningIfPossible()
        } else if centralManager.isScanning {
            centralManager.stopScan()
        }
    }

    func syncKnownDevices(_ devices: [DeviceRecord]) {
        knownDevices = Dictionary(uniqueKeysWithValues: devices.map {
            let uuid = $0.peripheralIdentifier.flatMap(UUID.init(uuidString:))
            return ($0.deviceID, KnownDeviceDescriptor(deviceID: $0.deviceID, peripheralIdentifier: uuid))
        })

        let validDeviceIDs = Set(devices.map(\.deviceID))
        connectionStates = Dictionary(uniqueKeysWithValues: devices.map { device in
            let peripheralID = device.peripheralIdentifier.flatMap(UUID.init(uuidString:))
            return (device.deviceID, resolvedConnectionState(for: peripheralID, deviceID: device.deviceID))
        })
        liveStates = liveStates.filter { validDeviceIDs.contains($0.key) }
        if debugMessages.count > 120 {
            debugMessages = Array(debugMessages.suffix(120))
        }

        updateNearbyList()
        beginScanningIfPossible()
    }

    func startOnboardingScan() {
        beginScanningIfPossible()
    }

    func stopOnboardingScan() {
        if centralManager.isScanning, !foregroundActive {
            centralManager.stopScan()
        }
    }

    func resolveNearbyDevice(for peripheralID: UUID) async throws -> NearbyResolvedDevice {
        guard let context = peripheralContexts[peripheralID] else {
            throw ModuleConfigError(message: "The selected peripheral is no longer available.")
        }

        if let identity = context.identityPayload, context.peripheral.state == .connected {
            return NearbyResolvedDevice(peripheralIdentifier: peripheralID, identity: identity)
        }

        if context.peripheral.state == .connected {
            return try await readIdentity(for: context.peripheral)
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingIdentityContinuations[peripheralID] = continuation
            autoConnectInFlight.insert(peripheralID)
            if let matchingKnownDevice = knownDevices.values.first(where: { $0.peripheralIdentifier == peripheralID }) {
                connectionStates[matchingKnownDevice.deviceID] = .connecting
            }
            appendDebug("Connecting to \(context.peripheral.name ?? peripheralID.uuidString) for onboarding")
            centralManager.connect(context.peripheral)
        }
    }

    func markDeviceAdded(deviceID: String, peripheralIdentifier: UUID?) {
        knownDevices[deviceID] = KnownDeviceDescriptor(deviceID: deviceID, peripheralIdentifier: peripheralIdentifier)
        if let peripheralIdentifier {
            autoConnectInFlight.remove(peripheralIdentifier)
        }
        updateNearbyList()
        beginScanningIfPossible()
    }

    func markDeviceRemoved(deviceID: String) {
        knownDevices.removeValue(forKey: deviceID)
        connectionStates.removeValue(forKey: deviceID)
        liveStates.removeValue(forKey: deviceID)
        updateNearbyList()
        beginScanningIfPossible()
    }

    func sendCommand(to deviceID: String, actionID: String, payload: [String: JSONValue]) {
        guard
            let peripheralID = peripheralContexts.first(where: { $0.value.identityPayload?.deviceID == deviceID })?.key,
            let context = peripheralContexts[peripheralID],
            let characteristic = context.commandCharacteristic
        else {
            appendDebug("Command skipped because \(deviceID) is not currently connected")
            return
        }

        let envelope = CommandEnvelope(action: actionID, payload: payload)

        do {
            let data = try encoder.encode(envelope)
            context.peripheral.writeValue(data, for: characteristic, type: .withResponse)
            applyOptimisticState(for: deviceID, actionID: actionID, payload: payload)
            appendDebug("Sent action \(actionID) to \(deviceID)")
        } catch {
            appendDebug("Failed to encode command \(actionID): \(error.localizedDescription)")
        }
    }

    private func applyOptimisticState(for deviceID: String, actionID: String, payload: [String: JSONValue]) {
        var state = liveStates[deviceID] ?? LiveDeviceState()
        switch actionID {
        case "motor_run_forward":
            state.values["motor_state"] = .string("forward")
        case "motor_run_reverse":
            state.values["motor_state"] = .string("reverse")
        case "motor_stop":
            state.values["motor_state"] = .string("stopped")
        case "set_display_enabled":
            if let enabled = payload["value"]?.boolValue {
                state.values["display_enabled"] = .bool(enabled)
            }
        default:
            return
        }

        state.lastUpdate = .now
        liveStates[deviceID] = state
    }

    private func beginScanningIfPossible() {
        guard foregroundActive || !pendingIdentityContinuations.isEmpty else {
            return
        }
        guard centralManager.state == .poweredOn else {
            appendDebug("Scan blocked because Bluetooth is \(centralManager.state.debugLabel)")
            return
        }
        guard !centralManager.isScanning else {
            return
        }

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        appendDebug("Started BLE scan for RetroSmart peripherals")
    }

    private func connectKnownDeviceIfNeeded(_ peripheral: CBPeripheral) {
        guard peripheral.state == .disconnected else {
            return
        }

        let matchesKnownPeripheral = knownDevices.values.contains { descriptor in
            descriptor.peripheralIdentifier == peripheral.identifier
        }

        guard matchesKnownPeripheral, !autoConnectInFlight.contains(peripheral.identifier) else {
            return
        }

        autoConnectInFlight.insert(peripheral.identifier)
        if let matchingKnownDevice = knownDevices.values.first(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            connectionStates[matchingKnownDevice.deviceID] = .connecting
        }
        centralManager.connect(peripheral)
    }

    private func readIdentity(for peripheral: CBPeripheral) async throws -> NearbyResolvedDevice {
        if let identity = peripheralContexts[peripheral.identifier]?.identityPayload {
            return NearbyResolvedDevice(peripheralIdentifier: peripheral.identifier, identity: identity)
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingIdentityContinuations[peripheral.identifier] = continuation
            peripheral.discoverServices([RetroSmartBLEContract.serviceUUID])
        }
    }

    private func updateNearbyList() {
        let knownPeripheralIDs = Set(knownDevices.values.compactMap(\.peripheralIdentifier))
        let knownDeviceIDs = Set(knownDevices.keys)

        nearbyPeripherals = peripheralContexts.values
            .filter { context in
                if knownPeripheralIDs.contains(context.peripheral.identifier) {
                    return false
                }

                if let deviceID = context.identityPayload?.deviceID, knownDeviceIDs.contains(deviceID) {
                    return false
                }

                return true
            }
            .map { context in
                NearbyPeripheral(
                    id: context.peripheral.identifier,
                    peripheralIdentifier: context.peripheral.identifier,
                    name: context.advertisedName ?? context.peripheral.name ?? "RetroSmart Device",
                    rssi: context.rssi
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func resolvedConnectionState(for peripheralID: UUID?, deviceID: String) -> DeviceConnectionState {
        guard let peripheralID, let context = peripheralContexts[peripheralID] else {
            return .disconnected
        }

        if autoConnectInFlight.contains(peripheralID) {
            return .connecting
        }

        if context.peripheral.state == .connected, context.identityPayload?.deviceID == deviceID {
            return .connected
        }

        if context.peripheral.state == .connecting {
            return .connecting
        }

        return .disconnected
    }

    private func markAllKnownDevicesDisconnected() {
        guard !connectionStates.isEmpty else {
            return
        }

        connectionStates = connectionStates.mapValues { _ in .disconnected }
    }

    private func updateConnectionState(for peripheralID: UUID, to state: DeviceConnectionState) {
        if let deviceID = peripheralContexts[peripheralID]?.identityPayload?.deviceID {
            connectionStates[deviceID] = state
            return
        }

        if let knownDevice = knownDevices.values.first(where: { $0.peripheralIdentifier == peripheralID }) {
            connectionStates[knownDevice.deviceID] = state
        }
    }

    private func failPendingIdentityResolution(for peripheralID: UUID, error: Error) {
        autoConnectInFlight.remove(peripheralID)
        pendingIdentityContinuations[peripheralID]?.resume(throwing: error)
        pendingIdentityContinuations[peripheralID] = nil
        updateConnectionState(for: peripheralID, to: .disconnected)
    }

    private func appendDebug(_ message: String) {
        let timestamp = Date.now.formatted(date: .omitted, time: .standard)
        debugMessages.append("[\(timestamp)] \(message)")
        if debugMessages.count > 120 {
            debugMessages.removeFirst(debugMessages.count - 120)
        }
    }

    private func isPotentialRetroSmartPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        if knownDevices.values.contains(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            return true
        }

        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           serviceUUIDs.contains(RetroSmartBLEContract.serviceUUID) {
            return true
        }

        if let overflowServiceUUIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID],
           overflowServiceUUIDs.contains(RetroSmartBLEContract.serviceUUID) {
            return true
        }

        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        return localName.localizedCaseInsensitiveContains("retrosmart")
    }

    private func advertisedServiceSummary(_ advertisementData: [String: Any]) -> String {
        let uuids = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []) +
            (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [])
        if uuids.isEmpty {
            return "no service UUIDs in advertisement"
        }

        return uuids.map(\.uuidString).joined(separator: ", ")
    }
}

extension RetroSmartBLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            self?.bluetoothState = central.state
            self?.appendDebug("Central state changed to \(central.state.debugLabel)")
            if central.state != .poweredOn {
                self?.autoConnectInFlight.removeAll()
                self?.markAllKnownDevicesDisconnected()
            }
            self?.beginScanningIfPossible()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.isPotentialRetroSmartPeripheral(peripheral, advertisementData: advertisementData) else {
                return
            }

            peripheral.delegate = self
            var context = self.peripheralContexts[peripheral.identifier] ?? PeripheralContext(peripheral: peripheral)
            if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
               !localName.isEmpty {
                context.advertisedName = localName
            }
            context.rssi = RSSI.intValue
            self.peripheralContexts[peripheral.identifier] = context
            self.appendDebug(
                "Discovered \((context.advertisedName ?? peripheral.name) ?? "Unnamed RetroSmart device") RSSI \(RSSI.intValue) " +
                "(\(self.advertisedServiceSummary(advertisementData)))"
            )
            self.updateNearbyList()
            self.connectKnownDeviceIfNeeded(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.appendDebug("Connected to \(peripheral.name ?? peripheral.identifier.uuidString)")
            peripheral.delegate = self
            peripheral.discoverServices([RetroSmartBLEContract.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.failPendingIdentityResolution(
                for: peripheral.identifier,
                error: error ?? ModuleConfigError(message: "Unable to connect to the selected peripheral.")
            )
            self.appendDebug("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            self.autoConnectInFlight.remove(peripheral.identifier)
            if self.pendingIdentityContinuations[peripheral.identifier] != nil {
                self.failPendingIdentityResolution(
                    for: peripheral.identifier,
                    error: error ?? ModuleConfigError(message: "The peripheral disconnected before identity could be read.")
                )
            }

            self.updateConnectionState(for: peripheral.identifier, to: .disconnected)

            self.appendDebug("Disconnected from \(peripheral.name ?? peripheral.identifier.uuidString)")
            if self.foregroundActive {
                self.connectKnownDeviceIfNeeded(peripheral)
            }
        }
    }
}

extension RetroSmartBLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                self.failPendingIdentityResolution(for: peripheral.identifier, error: error)
                self.appendDebug("Service discovery failed: \(error.localizedDescription)")
                return
            }

            let matchingServices = peripheral.services?.filter { $0.uuid == RetroSmartBLEContract.serviceUUID } ?? []
            guard !matchingServices.isEmpty else {
                let error = ModuleConfigError(message: "The selected peripheral connected, but it did not expose the RetroSmart BLE service.")
                self.failPendingIdentityResolution(for: peripheral.identifier, error: error)
                self.appendDebug("Connected peripheral did not expose the RetroSmart service")
                return
            }

            matchingServices.forEach { service in
                peripheral.discoverCharacteristics([
                    RetroSmartBLEContract.identityUUID,
                    RetroSmartBLEContract.capabilitiesUUID,
                    RetroSmartBLEContract.stateUUID,
                    RetroSmartBLEContract.commandUUID,
                ], for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                self.failPendingIdentityResolution(for: peripheral.identifier, error: error)
                self.appendDebug("Characteristic discovery failed: \(error.localizedDescription)")
                return
            }

            guard var context = self.peripheralContexts[peripheral.identifier] else {
                return
            }

            for characteristic in service.characteristics ?? [] {
                switch characteristic.uuid {
                case RetroSmartBLEContract.identityUUID:
                    context.identityCharacteristic = characteristic
                    peripheral.readValue(for: characteristic)
                case RetroSmartBLEContract.capabilitiesUUID:
                    context.capabilitiesCharacteristic = characteristic
                    peripheral.readValue(for: characteristic)
                case RetroSmartBLEContract.stateUUID:
                    context.stateCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                case RetroSmartBLEContract.commandUUID:
                    context.commandCharacteristic = characteristic
                default:
                    break
                }
            }

            self.peripheralContexts[peripheral.identifier] = context
            self.appendDebug("Characteristics ready for \(peripheral.name ?? peripheral.identifier.uuidString)")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard error == nil else {
                self.appendDebug("Characteristic update failed: \(error!.localizedDescription)")
                return
            }
            guard let data = characteristic.value else {
                return
            }

            if characteristic.uuid == RetroSmartBLEContract.identityUUID {
                do {
                    let identity = try self.decoder.decode(IdentityPayload.self, from: data)
                    guard var context = self.peripheralContexts[peripheral.identifier] else {
                        return
                    }

                    self.autoConnectInFlight.remove(peripheral.identifier)
                    context.identityPayload = identity
                    context.advertisedName = identity.model
                    self.peripheralContexts[peripheral.identifier] = context
                    self.connectionStates[identity.deviceID] = .connected
                    self.updateNearbyList()

                    if self.knownDevices[identity.deviceID] != nil {
                        self.knownDevices[identity.deviceID] = KnownDeviceDescriptor(
                            deviceID: identity.deviceID,
                            peripheralIdentifier: peripheral.identifier
                        )
                    }

                    self.pendingIdentityContinuations[peripheral.identifier]?.resume(
                        returning: NearbyResolvedDevice(peripheralIdentifier: peripheral.identifier, identity: identity)
                    )
                    self.pendingIdentityContinuations[peripheral.identifier] = nil
                    self.appendDebug("Identity loaded for \(identity.deviceID) as \(identity.deviceType)")
                } catch {
                    self.failPendingIdentityResolution(for: peripheral.identifier, error: error)
                    self.appendDebug("Failed to decode identity JSON: \(error.localizedDescription)")
                }
            } else if characteristic.uuid == RetroSmartBLEContract.capabilitiesUUID {
                guard let identity = self.peripheralContexts[peripheral.identifier]?.identityPayload else {
                    return
                }
                do {
                    let summary = try self.decoder.decode(CapabilitySummaryPayload.self, from: data)
                    var state = self.liveStates[identity.deviceID] ?? LiveDeviceState()
                    state.lastCapabilitySummary = summary
                    self.liveStates[identity.deviceID] = state
                    self.connectionStates[identity.deviceID] = .connected
                    self.appendDebug("Capabilities loaded for \(identity.deviceID)")
                } catch {
                    self.appendDebug("Failed to decode capabilities for \(identity.deviceID): \(error.localizedDescription)")
                }
            } else if characteristic.uuid == RetroSmartBLEContract.stateUUID {
                guard let identity = self.peripheralContexts[peripheral.identifier]?.identityPayload else {
                    return
                }
                do {
                    let payload = try self.decoder.decode(StatePayload.self, from: data)
                    var state = self.liveStates[identity.deviceID] ?? LiveDeviceState()
                    state.values = payload.flattenedValues
                    state.lastUpdate = .now
                    self.liveStates[identity.deviceID] = state
                    self.connectionStates[identity.deviceID] = .connected
                    self.appendDebug("State update received for \(identity.deviceID)")
                } catch {
                    self.appendDebug("Failed to decode state payload for \(identity.deviceID): \(error.localizedDescription)")
                }
            }
        }
    }
}

private extension CBManagerState {
    var debugLabel: String {
        switch self {
        case .unknown:
            return "unknown"
        case .resetting:
            return "resetting"
        case .unsupported:
            return "unsupported"
        case .unauthorized:
            return "unauthorized"
        case .poweredOff:
            return "powered off"
        case .poweredOn:
            return "powered on"
        @unknown default:
            return "unknown future state"
        }
    }
}
