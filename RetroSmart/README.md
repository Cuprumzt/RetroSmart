# RetroSmart v1 Prototype

RetroSmart is a local-first iOS + ESP32 retrofit smart-home prototype. Each physical module has its own ESP32, BLE identity, YAML type definition, and module-specific UI rendered by the app.

The persisted product requirements document for the current prototype lives at [RetroSmart-PRD.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/code/docs/RetroSmart-PRD.md).

## What is included

- SwiftUI iOS app with three tabs: `Devices`, `Automations`, and `RetroSmart AI`
- SwiftData persistence for devices, imported YAML type definitions, and automation rules
- Built-in YAML configs for:
  - `dc_motor_drv8833_v1`
  - `servo_180_v1`
  - `temperature_ds18b20_v1`
  - `air_quality_ens160_aht21_v1`
- YAML import from Files and raw paste import
- BLE manager using a fixed RetroSmart JSON-over-BLE contract
- Lightweight config-driven device page renderer
- Foreground-only automation engine
- Shared Arduino BLE scaffolding and initial firmware sketches for the four module types

## App architecture

- `RetroSmart/App`
  - app entry point and the shared app model
- `RetroSmart/Models`
  - SwiftData entities and typed config/BLE schema models
- `RetroSmart/Services`
  - YAML registry, BLE manager, and automation engine
- `RetroSmart/Views`
  - tabs, onboarding/import flows, dynamic device pages, settings, and automation editor
- `RetroSmart/Resources/BuiltInConfigs`
  - built-in YAML module definitions bundled into the app

The app uses a simple runtime flow:

1. SwiftData stores devices, imported configs, and automation rules.
2. `ModuleConfigRegistry` loads built-in YAML plus imported YAML and replaces definitions globally by `type_id`.
3. `RetroSmartBLEManager` scans for known peripherals, reads identity/capability/state JSON, and writes command JSON.
4. Device detail pages render widget primitives from YAML.
5. `AutomationEngine` evaluates simple rules only while the app is foregrounded.

## BLE contract

RetroSmart v1 uses UTF-8 JSON strings over BLE characteristics.

- Service UUID: `D973F2E0-71A7-4E26-A72A-4A130B83A001`
- Identity characteristic: `...A002`
- Capabilities characteristic: `...A003`
- State/readings characteristic: `...A004`
- Command characteristic: `...A005`

### Identity JSON

```json
{
  "device_id": "RS-DCM-001A92",
  "device_type": "dc_motor_drv8833_v1",
  "model": "DC Motor Module",
  "fw_version": "0.1.0"
}
```

### State JSON

State payloads use a stable envelope:

```json
{
  "device_id": "RS-SER-001A92",
  "readings": {
    "servo_angle": 45
  },
  "status": {
    "connection_hint": "connected"
  }
}
```

### Command JSON

```json
{
  "action": "set_servo_angle",
  "payload": {
    "value": 90
  }
}
```

## Config format

YAML is the source-of-truth authoring format. All module types include:

- `schema_version`
- `module`
- `identity`
- `ui`
- `capabilities`
- `automation`
- `hardware`
- `firmware`

Imported YAML is validated on-device. If a new import uses an existing `type_id`, it replaces that definition globally for all devices assigned to it. Imported configs cannot be deleted while any device still references them.

## Running the app

1. Open [RetroSmart.xcodeproj](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo Y/code/RetroSmart/RetroSmart.xcodeproj) in Xcode.
2. Select an iOS 17+ simulator or device.
3. Build and run the `RetroSmart` target.
4. Use the `Devices` tab to:
   - add a nearby RetroSmart BLE module
   - import a YAML file from Files
   - paste raw YAML

## Flashing firmware

Firmware lives under [firmware](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo Y/code/firmware).

1. Open the module sketch you want:
   - [dc_motor_drv8833_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo Y/code/firmware/modules/dc_motor_drv8833_v1/dc_motor_drv8833_v1.ino)
   - [servo_180_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo Y/code/firmware/modules/servo_180_v1/servo_180_v1.ino)
   - [temperature_ds18b20_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo Y/code/firmware/modules/temperature_ds18b20_v1/temperature_ds18b20_v1.ino)
   - [air_quality_ens160_aht21_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo Y/code/firmware/modules/air_quality_ens160_aht21_v1/air_quality_ens160_aht21_v1.ino)
2. Install the libraries listed in each YAML config and sketch comments.
3. For `ESP32-S3 Zero`, enable native USB serial in Arduino before flashing:
   - board: your ESP32-S3 target or ESP32-S3 Zero profile
   - `USB CDC On Boot`: `Enabled`
4. The built-in RetroSmart pin maps for `ESP32-S3 Zero` stay within `GPIO1-GPIO13`:
   - DC motor: `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional status LED `GPIO13`
   - Servo: `GPIO7` signal, optional status LED `GPIO13`
   - Temperature: `GPIO7` OneWire, optional status LED `GPIO13`
   - Air quality: `GPIO5` SDA, `GPIO6` SCL, optional status LED `GPIO13`
5. The board's onboard WS2812 on `GPIO21` is intentionally unused in this profile so all required wiring stays on the easy-access pins. `GPIO0` is also left alone because it is the BOOT pin.
6. Flash the sketch to the matching ESP32 module. If the board does not auto-enter download mode, hold `BOOT` while connecting or resetting it.
7. Open the serial monitor at `115200`, then power the module and onboard it from the app.

## Current limitations

- Automations run only while the app is foregrounded.
- The YAML parser is a deliberately small subset parser aimed at the v1 schema, not a full YAML implementation.
- BLE reconnection favors known peripheral identifiers and the device identity payload; this is appropriate for prototyping but not a production pairing system.
- The app keeps the dynamic renderer intentionally lightweight and only supports the first widget set in the PRD.
- Firmware templates are prototype-oriented and do not include OTA, cloud sync, or hardened security.
