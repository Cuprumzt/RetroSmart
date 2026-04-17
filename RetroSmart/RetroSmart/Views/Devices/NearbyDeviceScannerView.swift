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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScannerSummaryCard(bluetoothStateLabel: appModel.bleManager.bluetoothStateLabel)

                RetroSmartSectionHeader(
                    eyebrow: "Nearby",
                    title: "Discovered devices"
                )

                if appModel.bleManager.nearbyPeripherals.isEmpty {
                    RetroSmartEmptyStateCard(
                        title: "Scanning for RetroSmart devices",
                        message: "Keep the module powered nearby.",
                        systemImage: "dot.radiowaves.left.and.right",
                        tone: .accent
                    )
                } else {
                    ForEach(appModel.bleManager.nearbyPeripherals) { peripheral in
                        Button {
                            Task {
                                await resolve(peripheral: peripheral)
                            }
                        } label: {
                            NearbyDeviceRow(
                                peripheral: peripheral,
                                signalLabel: signalLabel(for: peripheral.rssi),
                                isResolving: resolvingPeripheralID == peripheral.peripheralIdentifier
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(resolvingPeripheralID != nil)
                    }
                }

                if hasTroubleshootingInfo {
                    ScannerTroubleshootingCard(
                        bluetoothStateLabel: appModel.bleManager.bluetoothStateLabel,
                        debugMessages: Array(appModel.bleManager.debugMessages.suffix(6)),
                        isExpanded: $showingTroubleshooting
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .retroSmartScreenBackground()
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

private struct ScannerSummaryCard: View {
    let bluetoothStateLabel: String

    private var isBluetoothReady: Bool {
        bluetoothStateLabel == "poweredOn"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby devices")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)

            RetroSmartTag(
                title: bluetoothStateLabel.capitalized,
                systemImage: "bolt.horizontal.circle",
                tone: isBluetoothReady ? .success : .warning
            )
        }
        .padding(20)
        .retroSmartSurface(tone: .accent)
    }
}

private struct NearbyDeviceRow: View {
    let peripheral: NearbyPeripheral
    let signalLabel: String
    let isResolving: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(RetroSmartTheme.accent.opacity(0.14))
                .foregroundStyle(RetroSmartTheme.accentStrong)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(peripheral.name)
                    .font(.headline)
                    .fontDesign(.rounded)

                Text(signalLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isResolving {
                ProgressView()
                    .tint(RetroSmartTheme.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .retroSmartSurface()
    }
}

private struct ScannerTroubleshootingCard: View {
    let bluetoothStateLabel: String
    let debugMessages: [String]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup("Troubleshooting", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Bluetooth", value: bluetoothStateLabel.capitalized)
                    .font(.subheadline)

                if bluetoothStateLabel != "poweredOn" {
                    Text("Turn on Bluetooth for RetroSmart.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("If it still does not appear, check ESP32 advertising.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !debugMessages.isEmpty {
                    Divider()

                    ForEach(debugMessages, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 10)
        }
        .tint(.primary)
        .padding(20)
        .retroSmartSurface()
    }
}
