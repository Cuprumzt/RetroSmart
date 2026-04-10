import Foundation

struct LoadedModuleConfig: Identifiable, Equatable {
    enum Source: String {
        case builtIn = "Built-in"
        case imported = "Imported"
    }

    var id: String { config.module.typeID }
    let config: ModuleConfig
    let source: Source
    let sourceName: String
    let rawYAML: String
}

struct ModuleConfig: Equatable {
    let schemaVersion: Int
    let module: ModuleMetadata
    let identity: ModuleIdentity
    let ui: ModuleUI
    let capabilities: ModuleCapabilities
    let automation: ModuleAutomation
    let hardware: HardwareDefinition
    let firmware: FirmwareDefinition

    init(yaml: YAMLValue) throws {
        let root = try yaml.requireDictionary(context: "root")

        schemaVersion = try root.requireInt("schema_version", context: "root")
        module = try ModuleMetadata(yaml: root.requireValue("module", context: "root"))
        identity = try ModuleIdentity(yaml: root.requireValue("identity", context: "root"))
        ui = try ModuleUI(yaml: root.requireValue("ui", context: "root"))
        capabilities = try ModuleCapabilities(yaml: root.requireValue("capabilities", context: "root"))
        automation = try ModuleAutomation(yaml: root.requireValue("automation", context: "root"))
        hardware = try HardwareDefinition(yaml: root.requireValue("hardware", context: "root"))
        firmware = try FirmwareDefinition(yaml: root.requireValue("firmware", context: "root"))
    }
}

struct ModuleMetadata: Equatable {
    let typeID: String
    let displayName: String
    let category: String
    let description: String
    let manufacturer: String
    let firmwareFamily: String

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "module")
        typeID = try dictionary.requireString("type_id", context: "module")
        displayName = try dictionary.requireString("display_name", context: "module")
        category = try dictionary.requireString("category", context: "module")
        description = dictionary.string("description") ?? ""
        manufacturer = dictionary.string("manufacturer") ?? "RetroSmart"
        firmwareFamily = dictionary.string("firmware_family") ?? "retrosmart_esp32_ble_v1"
    }
}

struct ModuleIdentity: Equatable {
    let ble: BLEIdentity

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "identity")
        ble = try BLEIdentity(yaml: dictionary.requireValue("ble", context: "identity"))
    }
}

struct BLEIdentity: Equatable {
    let serviceUUID: String
    let deviceTypeKey: String
    let exposesUniqueID: Bool

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "identity.ble")
        serviceUUID = dictionary.string("service_uuid") ?? RetroSmartBLEContract.serviceUUID.uuidString.lowercased()
        deviceTypeKey = try dictionary.requireString("device_type_key", context: "identity.ble")
        exposesUniqueID = dictionary.bool("exposes_unique_id") ?? true
    }
}

struct ModuleUI: Equatable {
    let iconSuggestions: [String]
    let devicePage: DevicePageConfig
    let settingsPage: SettingsPageConfig

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "ui")
        iconSuggestions = dictionary.arrayStrings("icon_suggestions") ?? []
        devicePage = try DevicePageConfig(yaml: dictionary.requireValue("device_page", context: "ui"))
        settingsPage = try SettingsPageConfig(yaml: dictionary.requireValue("settings_page", context: "ui"))
    }
}

struct DevicePageConfig: Equatable {
    let layout: String
    let widgets: [WidgetConfig]

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "ui.device_page")
        layout = dictionary.string("layout") ?? "controls_primary"
        widgets = try dictionary.requireArray("widgets", context: "ui.device_page").map {
            try WidgetConfig(yaml: $0)
        }
    }
}

struct SettingsPageConfig: Equatable {
    let showConfigText: Bool
    let showPinout: Bool
    let editableFields: [String]

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "ui.settings_page")
        showConfigText = dictionary.bool("show_config_text") ?? true
        showPinout = dictionary.bool("show_pinout") ?? true
        editableFields = dictionary.arrayStrings("editable_fields") ?? ["custom_name", "custom_icon", "assigned_type"]
    }
}

enum WidgetType: String {
    case section
    case text
    case status
    case button
    case holdButton = "hold_button"
    case slider
    case reading
    case toggle
}

struct WidgetConfig: Equatable, Identifiable {
    let type: WidgetType
    let id: String
    let label: String?
    let action: String?
    let releaseAction: String?
    let source: String?
    let min: Double?
    let max: Double?
    let text: String?
    let unit: String?
    let widgets: [WidgetConfig]
    let visibleWhenSource: String?
    let visibleWhenEquals: String?

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "ui.device_page.widgets[]")

        guard let typeString = dictionary.string("type"), let resolvedType = WidgetType(rawValue: typeString) else {
            throw ModuleConfigError(message: "Unsupported widget type in ui.device_page.widgets")
        }

        type = resolvedType
        id = dictionary.string("id") ?? UUID().uuidString
        label = dictionary.string("label")
        action = dictionary.string("action")
        releaseAction = dictionary.string("release_action")
        source = dictionary.string("source")
        min = dictionary.double("min")
        max = dictionary.double("max")
        text = dictionary.string("text")
        unit = dictionary.string("unit")
        widgets = try (dictionary.array("widgets") ?? []).map { try WidgetConfig(yaml: $0) }
        visibleWhenSource = dictionary.string("visible_when_source")
        if let boolValue = dictionary.bool("visible_when_equals") {
            visibleWhenEquals = boolValue ? "true" : "false"
        } else if let stringValue = dictionary.string("visible_when_equals") {
            visibleWhenEquals = stringValue
        } else if let intValue = dictionary.int("visible_when_equals") {
            visibleWhenEquals = String(intValue)
        } else if let doubleValue = dictionary.double("visible_when_equals") {
            visibleWhenEquals = String(doubleValue)
        } else {
            visibleWhenEquals = nil
        }
    }
}

struct ModuleCapabilities: Equatable {
    let actions: [ActionCapability]
    let readings: [ReadingCapability]

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "capabilities")
        actions = try (dictionary.array("actions") ?? []).map { try ActionCapability(yaml: $0) }
        readings = try (dictionary.array("readings") ?? []).map { try ReadingCapability(yaml: $0) }
    }
}

struct ActionCapability: Equatable, Identifiable {
    let id: String
    let label: String
    let kind: String
    let payload: PayloadDefinition

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "capabilities.actions[]")
        id = try dictionary.requireString("id", context: "capabilities.actions[]")
        label = dictionary.string("label") ?? id
        kind = dictionary.string("kind") ?? "command"
        payload = try PayloadDefinition(yaml: dictionary.value("payload") ?? .dictionary([:]))
    }
}

struct ReadingCapability: Equatable, Identifiable {
    let id: String
    let label: String
    let type: String
    let unit: String?
    let values: [String]

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "capabilities.readings[]")
        id = try dictionary.requireString("id", context: "capabilities.readings[]")
        label = dictionary.string("label") ?? id
        type = dictionary.string("type") ?? "string"
        unit = dictionary.string("unit")
        values = dictionary.arrayStrings("values") ?? []
    }
}

struct PayloadDefinition: Equatable {
    let type: String
    let min: Double?
    let max: Double?

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "payload")
        type = dictionary.string("type") ?? "none"
        min = dictionary.double("min")
        max = dictionary.double("max")
    }
}

struct ModuleAutomation: Equatable {
    let triggers: [String]
    let actions: [String]

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "automation")
        triggers = dictionary.arrayStrings("triggers") ?? []
        actions = dictionary.arrayStrings("actions") ?? []
    }
}

struct HardwareDefinition: Equatable {
    let board: String
    let interfaces: [String: String]
    let pinout: [String: String]

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "hardware")
        board = dictionary.string("board") ?? "esp32"
        interfaces = dictionary.dictionaryStrings("interfaces") ?? [:]
        pinout = dictionary.dictionaryStrings("pinout") ?? [:]
    }
}

struct FirmwareDefinition: Equatable {
    let transport: String
    let codegen: CodegenDefinition

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "firmware")
        transport = dictionary.string("transport") ?? "ble"
        codegen = try CodegenDefinition(yaml: dictionary.requireValue("codegen", context: "firmware"))
    }
}

struct CodegenDefinition: Equatable {
    let template: String
    let requiredLibraries: [String]
    let updateModel: String

    init(yaml: YAMLValue) throws {
        let dictionary = try yaml.requireDictionary(context: "firmware.codegen")
        template = try dictionary.requireString("template", context: "firmware.codegen")
        requiredLibraries = dictionary.arrayStrings("required_libraries") ?? []
        updateModel = dictionary.string("update_model") ?? "command_based"
    }
}

struct ModuleConfigError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
