import SwiftData
import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: [SortDescriptor(\DeviceRecord.insertionIndex, order: .forward)]) private var devices: [DeviceRecord]
    @Query(sort: [SortDescriptor(\ImportedDeviceTypeRecord.importedAt, order: .forward)]) private var importedConfigs: [ImportedDeviceTypeRecord]
    @Query(sort: [SortDescriptor(\AutomationRuleRecord.createdAt, order: .forward)]) private var automations: [AutomationRuleRecord]

    init() {}

    private var syncToken: String {
        let deviceToken = devices
            .map { "\($0.deviceID)|\($0.assignedTypeID)|\($0.peripheralIdentifier ?? "")|\($0.customName)" }
            .joined(separator: ";")
        let configToken = importedConfigs
            .map { "\($0.typeID)|\($0.importedAt.timeIntervalSince1970)" }
            .joined(separator: ";")
        let automationToken = automations
            .map { "\($0.id.uuidString)|\($0.isEnabled)|\($0.triggerDeviceID)|\($0.actionDeviceID)" }
            .joined(separator: ";")
        return [deviceToken, configToken, automationToken].joined(separator: "||")
    }

    var body: some View {
        TabView {
            NavigationStack {
                DevicesListView()
            }
            .tabItem {
                Label("Devices", systemImage: "switch.2")
            }

            NavigationStack {
                AutomationsListView()
            }
            .tabItem {
                Label("Automations", systemImage: "bolt.badge.automatic")
            }

            NavigationStack {
                AIPlaceholderView()
            }
            .tabItem {
                Label("RetroSmart AI", systemImage: "sparkles.rectangle.stack")
            }
        }
        .onChange(of: syncToken, initial: true) { _, _ in
            appModel.sync(
                devices: devices,
                importedConfigs: importedConfigs,
                automations: automations
            )
        }
    }
}
