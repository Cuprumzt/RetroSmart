import CoreBluetooth
import Foundation

enum RetroSmartBLEContract {
    static let serviceUUID = CBUUID(string: "D973F2E0-71A7-4E26-A72A-4A130B83A001")
    static let identityUUID = CBUUID(string: "D973F2E0-71A7-4E26-A72A-4A130B83A002")
    static let capabilitiesUUID = CBUUID(string: "D973F2E0-71A7-4E26-A72A-4A130B83A003")
    static let stateUUID = CBUUID(string: "D973F2E0-71A7-4E26-A72A-4A130B83A004")
    static let commandUUID = CBUUID(string: "D973F2E0-71A7-4E26-A72A-4A130B83A005")
}

struct IdentityPayload: Codable, Equatable {
    let deviceID: String
    let deviceType: String
    let model: String
    let fwVersion: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceType = "device_type"
        case model
        case fwVersion = "fw_version"
    }
}

struct CapabilitySummaryPayload: Codable, Equatable {
    let deviceID: String?
    let deviceType: String?
    let actions: [String]
    let readings: [String]

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceType = "device_type"
        case actions
        case readings
    }
}

struct CommandEnvelope: Codable, Equatable {
    let action: String
    let payload: [String: JSONValue]
}

struct StatePayload: Codable, Equatable {
    let deviceID: String?
    let readings: [String: JSONValue]
    let status: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case readings
        case status
    }

    var flattenedValues: [String: JSONValue] {
        readings.merging(status) { _, new in new }
    }
}

enum JSONValue: Codable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return value.formatted(.number.precision(.fractionLength(0...2)))
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let value):
            return value.map { "\($0.key)=\($0.value.stringValue)" }.sorted().joined(separator: ", ")
        case .array(let value):
            return value.map(\.stringValue).joined(separator: ", ")
        case .null:
            return "n/a"
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        case .string(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .string(let value):
            return Bool(value.lowercased())
        case .int(let value):
            return value != 0
        case .double(let value):
            return value != 0
        default:
            return nil
        }
    }
}

enum DeviceConnectionState: String, CaseIterable {
    case disconnected
    case connecting
    case connected

    var label: String {
        switch self {
        case .disconnected:
            return "Offline"
        case .connecting:
            return "Joining"
        case .connected:
            return "Online"
        }
    }
}

struct LiveDeviceState: Equatable {
    var values: [String: JSONValue] = [:]
    var lastUpdate: Date?
    var lastCapabilitySummary: CapabilitySummaryPayload?
}
