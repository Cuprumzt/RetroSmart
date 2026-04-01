import Foundation
import SwiftData

@MainActor
final class ModuleConfigRegistry: ObservableObject {
    @Published private(set) var loadedConfigs: [LoadedModuleConfig] = []

    private let parser = YAMLSubsetParser()
    private let builtInConfigNames = [
        "dc_motor_drv8833_v1",
        "servo_180_v1",
        "temperature_ds18b20_v1",
        "air_quality_ens160_aht21_v1",
    ]

    func reload(importedConfigs: [ImportedDeviceTypeRecord]) {
        var combined: [LoadedModuleConfig] = loadBuiltInConfigs()

        for record in importedConfigs.sorted(by: { $0.importedAt < $1.importedAt }) {
            do {
                let parsed = try parseConfig(yamlText: record.yamlText, source: .imported, sourceName: record.sourceName)
                combined.removeAll { $0.config.module.typeID == parsed.config.module.typeID }
                combined.append(parsed)
            } catch {
                print("Ignoring invalid imported config \(record.typeID): \(error.localizedDescription)")
            }
        }

        loadedConfigs = combined.sorted {
            $0.config.module.displayName.localizedCaseInsensitiveCompare($1.config.module.displayName) == .orderedAscending
        }
    }

    func config(for typeID: String) -> LoadedModuleConfig? {
        loadedConfigs.first { $0.config.module.typeID == typeID }
    }

    func availableTypeIDs() -> [String] {
        loadedConfigs.map { $0.config.module.typeID }
    }

    func validate(yamlText: String) throws -> ModuleConfig {
        try parseConfig(yamlText: yamlText, source: .imported, sourceName: "Validation").config
    }

    func importConfig(yamlText: String, sourceName: String, modelContext: ModelContext) throws -> ModuleConfig {
        let loaded = try parseConfig(yamlText: yamlText, source: .imported, sourceName: sourceName)
        let typeID = loaded.config.module.typeID

        let descriptor = FetchDescriptor<ImportedDeviceTypeRecord>(
            predicate: #Predicate { record in
                record.typeID == typeID
            }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.yamlText = yamlText
            existing.sourceName = sourceName
            existing.importedAt = .now
        } else {
            modelContext.insert(
                ImportedDeviceTypeRecord(
                    typeID: loaded.config.module.typeID,
                    yamlText: yamlText,
                    sourceName: sourceName
                )
            )
        }

        try modelContext.save()
        return loaded.config
    }

    func deleteImportedConfig(
        typeID: String,
        assignedDeviceCount: Int,
        modelContext: ModelContext
    ) throws {
        guard assignedDeviceCount == 0 else {
            throw ModuleConfigError(message: "This type is assigned to \(assignedDeviceCount) device(s). Reassign those devices before deleting the config.")
        }

        let descriptor = FetchDescriptor<ImportedDeviceTypeRecord>(
            predicate: #Predicate { record in
                record.typeID == typeID
            }
        )

        guard let record = try modelContext.fetch(descriptor).first else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func loadBuiltInConfigs() -> [LoadedModuleConfig] {
        builtInConfigNames.compactMap { configName in
            do {
                guard let url = Bundle.main.url(forResource: configName, withExtension: "yaml") ??
                    Bundle.main.url(forResource: configName, withExtension: "yaml", subdirectory: "BuiltInConfigs")
                else {
                    return nil
                }
                let yaml = try String(contentsOf: url)
                return try parseConfig(yamlText: yaml, source: .builtIn, sourceName: url.lastPathComponent)
            } catch {
                print("Failed to load built-in config \(configName): \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func parseConfig(yamlText: String, source: LoadedModuleConfig.Source, sourceName: String) throws -> LoadedModuleConfig {
        let parsedYAML = try parser.parse(yamlText)
        let config = try ModuleConfig(yaml: parsedYAML)

        guard config.schemaVersion == 1 else {
            throw ModuleConfigError(message: "Unsupported schema_version \(config.schemaVersion). RetroSmart v1 expects schema_version: 1.")
        }

        return LoadedModuleConfig(config: config, source: source, sourceName: sourceName, rawYAML: yamlText)
    }
}
