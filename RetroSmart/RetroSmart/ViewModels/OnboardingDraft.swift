import Foundation

struct DeviceOnboardingDraft: Identifiable {
    let peripheralIdentifier: UUID
    let deviceID: String
    let advertisedTypeID: String
    let modelName: String
    let firmwareVersion: String
    var customName: String
    var iconSystemName: String
    var assignedTypeID: String

    var id: String { deviceID }
}
