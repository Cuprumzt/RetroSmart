import SwiftData
import SwiftUI

@main
struct RetroSmartApp: App {
    @StateObject private var appModel = AppModel()

    private let sharedModelContainer: ModelContainer = {
        do {
            let fileManager = FileManager.default
            let applicationSupportURL = try appSupportDirectory(fileManager: fileManager)
            let storeURL = applicationSupportURL.appendingPathComponent("RetroSmart.store")

            return try ModelContainer(
                for: DeviceRecord.self,
                ImportedDeviceTypeRecord.self,
                AutomationRuleRecord.self,
                configurations: ModelConfiguration("RetroSmart", url: storeURL)
            )
        } catch {
            fatalError("Unable to create RetroSmart model container: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase, initial: true) { _, newValue in
            appModel.setForegroundActive(newValue == .active)
        }
    }
}

private func appSupportDirectory(fileManager: FileManager) throws -> URL {
    let baseURL = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )

    let directoryURL = baseURL.appendingPathComponent("RetroSmart", isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
}
