import Foundation
import SwiftData

@Model
final class DeviceRecord {
    @Attribute(.unique) var deviceID: String
    var customName: String
    var iconSystemName: String
    var assignedTypeID: String
    var advertisedTypeID: String
    var modelName: String
    var firmwareVersion: String
    var peripheralIdentifier: String?
    var addedAt: Date
    var lastSeenAt: Date?
    var insertionIndex: Int

    init(
        deviceID: String,
        customName: String,
        iconSystemName: String,
        assignedTypeID: String,
        advertisedTypeID: String,
        modelName: String,
        firmwareVersion: String,
        peripheralIdentifier: String?,
        addedAt: Date = .now,
        lastSeenAt: Date? = nil,
        insertionIndex: Int
    ) {
        self.deviceID = deviceID
        self.customName = customName
        self.iconSystemName = iconSystemName
        self.assignedTypeID = assignedTypeID
        self.advertisedTypeID = advertisedTypeID
        self.modelName = modelName
        self.firmwareVersion = firmwareVersion
        self.peripheralIdentifier = peripheralIdentifier
        self.addedAt = addedAt
        self.lastSeenAt = lastSeenAt
        self.insertionIndex = insertionIndex
    }
}

@Model
final class ImportedDeviceTypeRecord {
    @Attribute(.unique) var typeID: String
    var yamlText: String
    var sourceName: String
    var importedAt: Date

    init(typeID: String, yamlText: String, sourceName: String, importedAt: Date = .now) {
        self.typeID = typeID
        self.yamlText = yamlText
        self.sourceName = sourceName
        self.importedAt = importedAt
    }
}

@Model
final class AutomationRuleRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var isEnabled: Bool
    var triggerDeviceID: String
    var triggerSourceID: String
    var comparison: String
    var triggerValue: String
    var actionDeviceID: String
    var actionID: String
    var actionValue: String?
    var createdAt: Date
    var lastTriggeredAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        triggerDeviceID: String,
        triggerSourceID: String,
        comparison: String,
        triggerValue: String,
        actionDeviceID: String,
        actionID: String,
        actionValue: String? = nil,
        createdAt: Date = .now,
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.triggerDeviceID = triggerDeviceID
        self.triggerSourceID = triggerSourceID
        self.comparison = comparison
        self.triggerValue = triggerValue
        self.actionDeviceID = actionDeviceID
        self.actionID = actionID
        self.actionValue = actionValue
        self.createdAt = createdAt
        self.lastTriggeredAt = lastTriggeredAt
    }
}

enum AutomationComparisonKind: String, CaseIterable, Identifiable {
    case above
    case below
    case equals

    var id: String { rawValue }

    var label: String {
        switch self {
        case .above:
            return "Above"
        case .below:
            return "Below"
        case .equals:
            return "Equals"
        }
    }
}
