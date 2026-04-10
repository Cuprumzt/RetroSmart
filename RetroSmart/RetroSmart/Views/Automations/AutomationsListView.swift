import SwiftData
import SwiftUI

struct AutomationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AutomationRuleRecord.createdAt, order: .forward)]) private var automations: [AutomationRuleRecord]
    @Query(sort: [SortDescriptor(\DeviceRecord.insertionIndex, order: .forward)]) private var devices: [DeviceRecord]

    @State private var presentedRule: AutomationRuleRecord?
    @State private var creatingNewRule = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if automations.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No automations yet")
                            .font(.headline)
                        Text("Automations evaluate simple single-trigger single-action rules while the app is foregrounded.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }

            Section("Rules") {
                ForEach(automations) { rule in
                    Button {
                        presentedRule = rule
                    } label: {
                        AutomationRowView(rule: rule, devices: devices)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    do {
                        indexSet.map { automations[$0] }.forEach(modelContext.delete)
                        try modelContext.save()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .navigationTitle("Automations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creatingNewRule = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(devices.count < 2)
            }
        }
        .sheet(item: $presentedRule) { rule in
            NavigationStack {
                AutomationEditorView(editingRule: rule)
            }
        }
        .sheet(isPresented: $creatingNewRule) {
            NavigationStack {
                AutomationEditorView()
            }
        }
        .alert("Automations", isPresented: errorAlertIsPresented) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
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

private struct AutomationRowView: View {
    let rule: AutomationRuleRecord
    let devices: [DeviceRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(rule.name)
                    .font(.headline)
                Spacer()
                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill")
                    .foregroundStyle(rule.isEnabled ? .green : .secondary)
            }

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        let triggerName = devices.first(where: { $0.deviceID == rule.triggerDeviceID })?.customName ?? rule.triggerDeviceID
        let actionName = devices.first(where: { $0.deviceID == rule.actionDeviceID })?.customName ?? rule.actionDeviceID
        let comparison = AutomationComparisonKind(rawValue: rule.comparison)?.label ?? rule.comparison
        return "If \(triggerName) \(rule.triggerSourceID) is \(comparison.lowercased()) \(rule.triggerValue), then \(actionName) runs \(rule.actionID)."
    }
}
