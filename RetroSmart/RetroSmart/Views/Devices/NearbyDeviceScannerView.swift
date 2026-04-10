import SwiftUI

struct NearbyDeviceScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedDraft: DeviceOnboardingDraft?
    @State private var errorMessage: String?
    @State private var resolvingPeripheralID: UUID?
    @State private var showingTroubleshooting = false

    private var hasTroubleshootingInfo: Bool {
        appModel.bleManager.bluetoothState != .poweredOn || !appModel.bleManager.debugMessages.isEmpty
    }

    var body: some View {
        List {
            Section("Discovered Devices") {
                if appModel.bleManager.nearbyPeripherals.isEmpty {
                    Label("Scanning for RetroSmart devices…", systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                }

                ForEach(appModel.bleManager.nearbyPeripherals) { peripheral in
                    Button {
                        Task {
                            await resolve(peripheral: peripheral)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(peripheral.name)
                                    .font(.headline)
                                Text(signalLabel(for: peripheral.rssi))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if resolvingPeripheralID == peripheral.peripheralIdentifier {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(resolvingPeripheralID != nil)
                }
            }

            if hasTroubleshootingInfo {
                Section {
                    DisclosureGroup("Troubleshooting", isExpanded: $showingTroubleshooting) {
                        LabeledContent("Bluetooth", value: appModel.bleManager.bluetoothStateLabel.capitalized)
                            .font(.subheadline)

                        if appModel.bleManager.bluetoothState != .poweredOn {
                            Text("Bluetooth must be powered on and allowed for RetroSmart before nearby modules can appear.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("If your module still does not appear, check the ESP32 serial monitor and confirm advertising started.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !appModel.bleManager.debugMessages.isEmpty {
                            Divider()
                            ForEach(appModel.bleManager.debugMessages.suffix(6), id: \.self) { message in
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Add Nearby Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Rescan") {
                    appModel.bleManager.stopOnboardingScan()
                    appModel.bleManager.startOnboardingScan()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedDraft) { draft in
            NavigationStack {
                DeviceOnboardingView(draft: draft) {
                    dismiss()
                }
            }
        }
        .alert("Unable to Read Device", isPresented: errorAlertIsPresented, actions: {
            Button("OK") {
                errorMessage = nil
            }
        }, message: {
            Text(errorMessage ?? "")
        })
        .task {
            appModel.bleManager.startOnboardingScan()
        }
        .onDisappear {
            appModel.bleManager.stopOnboardingScan()
        }
    }

    private func resolve(peripheral: NearbyPeripheral) async {
        resolvingPeripheralID = peripheral.peripheralIdentifier
        defer { resolvingPeripheralID = nil }

        do {
            let resolved = try await appModel.bleManager.resolveNearbyDevice(for: peripheral.peripheralIdentifier)
            selectedDraft = DeviceOnboardingDraft(
                peripheralIdentifier: resolved.peripheralIdentifier,
                deviceID: resolved.identity.deviceID,
                advertisedTypeID: resolved.identity.deviceType,
                modelName: resolved.identity.model,
                firmwareVersion: resolved.identity.fwVersion,
                customName: resolved.identity.model,
                iconSystemName: appModel.configRegistry.config(for: resolved.identity.deviceType)?.config.ui.iconSuggestions.first ?? "switch.2",
                assignedTypeID: resolved.identity.deviceType
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signalLabel(for rssi: Int) -> String {
        switch rssi {
        case -65...0:
            return "Strong signal"
        case -80 ..< -65:
            return "Nearby"
        default:
            return "Farther away"
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
