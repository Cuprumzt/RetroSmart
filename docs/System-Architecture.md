# System Architecture

RetroSmart has three main definition layers:

1. persisted app/device data
2. YAML module definitions
3. firmware BLE implementation

The app is configuration-driven, but deliberately bounded. It uses a small set of widget primitives, a fixed BLE contract, and foreground-only automation execution.

## Main Components

### iOS app

- SwiftUI for navigation and UI
- SwiftData for persistence
- CoreBluetooth for BLE discovery and control
- lightweight local automation engine

### Firmware

- Arduino-based ESP32 module sketches
- shared BLE helper for the RetroSmart JSON contract
- per-module logic for sensors and actuators
- optional SSD1306 OLED helper for sensor modules

### Config layer

- YAML module definitions bundled into the app
- imported YAML can replace built-in definitions by matching `type_id`
- configs describe UI widgets, readings, actions, automation compatibility, pinout, and required libraries

## App Structure

- [RetroSmart/App](../RetroSmart/RetroSmart/App)
  app entry point and shared model
- [RetroSmart/Models](../RetroSmart/RetroSmart/Models)
  persistence and BLE/config schema models
- [RetroSmart/Services](../RetroSmart/RetroSmart/Services)
  config registry, BLE manager, automation engine
- [RetroSmart/Views](../RetroSmart/RetroSmart/Views)
  app UI and device flows
- [RetroSmart/Resources/BuiltInConfigs](../RetroSmart/RetroSmart/Resources/BuiltInConfigs)
  bundled module YAML definitions

## Runtime Flow

1. SwiftData loads known devices, imported configs, and automation rules.
2. `ModuleConfigRegistry` loads built-in YAML and overlays imported YAML by `type_id`.
3. `RetroSmartBLEManager` scans for peripherals, resolves identity, subscribes to state, and writes commands.
4. Device pages render widget primitives from the selected module config.
5. `AutomationEngine` evaluates foreground-only trigger/action rules and can execute a saved rule manually from the list.

## BLE Contract

RetroSmart v1 uses UTF-8 JSON over a fixed BLE service and four characteristics.

### UUIDs

- service: `D973F2E0-71A7-4E26-A72A-4A130B83A001`
- identity: `...A002`
- capabilities: `...A003`
- state: `...A004`
- command: `...A005`

### Identity payload

Required fields:

- `device_id`
- `device_type`
- `model`
- `fw_version`

### Capabilities payload

Used by the app to understand:

- action ids
- reading ids

The YAML config still owns labels, payload types, UI widgets, and automation eligibility.

### State payload

Carries:

- `readings`
- `status`

The app flattens those into the live device state map.

### Command payload

Commands use:

- `action`
- optional `payload`

Example:

```json
{
  "action": "set_display_enabled",
  "payload": {
    "value": true
  }
}
```

## Automation Model

Automations are local app rules. They are persisted with SwiftData and evaluated only while the app is foregrounded.

Supported trigger modes:

- device reading above threshold
- device reading below threshold
- device reading equals value or category
- time of day while the app is open

Supported action targets:

- actuator actions declared in module YAML
- sensor display toggle actions declared in module YAML

Special app-side behavior:

- motor forward/reverse automation actions can store a run duration
- the app sends `motor_stop` after that duration if it is still active and connected
- tapping the play button on a saved automation manually executes the action path

This is not a background scheduling system. Time triggers do not run after iOS suspends the app.

## YAML Responsibility Split

YAML definitions tell the app:

- how to label the module
- which widgets to render
- which actions and readings exist
- which actions and readings participate in automations
- which pin map is expected
- which Arduino libraries are needed

Firmware still owns:

- actual sensor/actuator behavior
- pin initialization
- state publication
- command handling
- safety behavior such as stopping motors when disconnected

## Current Scaling Point

The first serious scaling pressure is BLE concurrency on iOS, not storage or rendering.

Current prototype assumptions:

- multiple known devices are supported
- several devices may reconnect while the app is active
- the documented target is up to 8 known devices

The architecture is practical for a prototype household, but it is not yet hardened for large concurrent BLE fleets.

## Design Intent

The project deliberately favors:

- inspectability over abstraction
- explicit module behavior over plugin magic
- practical extension over framework cleverness

Some things are intentionally narrow:

- YAML parsing
- widget types
- automation logic
- BLE protocol scope

Those constraints are part of the architecture, not accidental omissions.
