# RetroSmart iOS App

This directory contains the iPhone app for RetroSmart.

The project-level overview lives in the root [README](../README.md). Product behavior and prototype scope are tracked in the [PRD](../docs/RetroSmart-PRD.md).

## App Scope

- SwiftUI iOS app with three tabs: `Devices`, `Automations`, and `RetroSmart AI`
- SwiftData persistence for devices, imported YAML type definitions, and automation rules
- Built-in YAML configs for:
  - `dc_motor_drv8833_v1`
  - `servo_180_v1`
  - `temperature_ds18b20_v1`
  - `air_quality_sgp40_v1`
- YAML import from Files and raw paste import
- BLE manager using a fixed RetroSmart JSON-over-BLE contract
- Lightweight config-driven device page renderer
- Foreground-only automation engine
- Manual automation execution from the automation list
- Time-of-day automation triggers while the app is foregrounded
- Shared Arduino BLE scaffolding and firmware sketches for the built-in module types

## App Architecture

- [RetroSmart/App](./RetroSmart/App)
  app entry point and shared app model
- [RetroSmart/Models](./RetroSmart/Models)
  SwiftData entities and typed config/BLE schema models
- [RetroSmart/Services](./RetroSmart/Services)
  YAML registry, BLE manager, and automation engine
- [RetroSmart/Views](./RetroSmart/Views)
  tabs, onboarding/import flows, dynamic device pages, settings, and automation editor
- [RetroSmart/Resources/BuiltInConfigs](./RetroSmart/Resources/BuiltInConfigs)
  built-in YAML module definitions bundled into the app

Runtime flow:

1. SwiftData stores devices, imported configs, and automation rules.
2. `ModuleConfigRegistry` loads built-in YAML plus imported YAML and replaces definitions globally by `type_id`.
3. `RetroSmartBLEManager` scans for known peripherals, reads identity/capability/state JSON, and writes command JSON.
4. Device detail pages render widget primitives from YAML.
5. `AutomationEngine` evaluates simple foreground-only rules and can execute a saved rule manually from the list.

## BLE Contract

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
  "fw_version": "0.2.1"
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
    "connected": true
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

Boolean display commands use the same envelope:

```json
{
  "action": "set_display_enabled",
  "payload": {
    "value": true
  }
}
```

## Config Format

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

## Running The App

1. Open [RetroSmart.xcodeproj](./RetroSmart.xcodeproj) in Xcode.
2. Select an iOS 17+ simulator or device.
3. Build and run the `RetroSmart` target.
4. Use the `Devices` tab to:
   - add a nearby RetroSmart BLE module
   - import a YAML file from Files
   - paste raw YAML

For a smoother phone demo, edit the run scheme to use `Release` and uncheck `Debug executable`, or create an Xcode archive and install a development distribution build.

## Firmware Entry Points

Firmware lives under [firmware](../firmware).

Open the module sketch you want:

- [dc_motor_drv8833_v1.ino](../firmware/modules/dc_motor_drv8833_v1/dc_motor_drv8833_v1.ino)
- [servo_180_v1.ino](../firmware/modules/servo_180_v1/servo_180_v1.ino)
- [temperature_ds18b20_v1.ino](../firmware/modules/temperature_ds18b20_v1/temperature_ds18b20_v1.ino)
- [air_quality_sgp40_v1.ino](../firmware/modules/air_quality_sgp40_v1/air_quality_sgp40_v1.ino)

For `ESP32-S3 Zero`, enable native USB serial in Arduino before flashing:

- board: your ESP32-S3 target or ESP32-S3 Zero profile
- `USB CDC On Boot`: `Enabled`

The built-in RetroSmart pin maps for `ESP32-S3 Zero` stay within `GPIO1` through `GPIO13`:

- DC motor: `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional status LED `GPIO13`
- Servo: `GPIO7` signal, optional status LED `GPIO13`
- Temperature: `GPIO6` OneWire, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`
- Air quality: `GPIO5` SDA, `GPIO6` SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`

The board's onboard WS2812 on `GPIO21` is intentionally unused in this profile so all required wiring stays on the easy-access pins. `GPIO0` is also left alone because it is the BOOT pin.

## Related Docs

- [Getting Started](../docs/Getting-Started.md)
- [System Architecture](../docs/System-Architecture.md)
- [Module Authoring Guide](../docs/Module-Authoring-Guide.md)
- [Compatibility Matrix](../docs/Compatibility-Matrix.md)
- [Hardware Notes](../docs/Hardware-Notes.md)
- [Validation Checklist](../docs/Validation-Checklist.md)
- [Contributing Guide](../docs/Contributing-Guide.md)

## Current Limitations

- Automations run only while the app is foregrounded.
- Time triggers are app-foreground checks, not background schedules.
- The YAML parser is a deliberately small subset parser aimed at the v1 schema, not a full YAML implementation.
- BLE reconnection favors known peripheral identifiers and the device identity payload; this is appropriate for prototyping but not a production pairing system.
- The app keeps the dynamic renderer intentionally lightweight and only supports the first widget set in the PRD.
- Firmware templates are prototype-oriented and do not include OTA, cloud sync, or hardened security.
