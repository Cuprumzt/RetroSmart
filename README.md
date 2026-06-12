# RetroSmart

RetroSmart is an open hardware and software retrofit platform for building modular smart-home devices around an iPhone app and ESP32-based modules.

The project is designed to stay inspectable:

- the iPhone app source is included
- module firmware is included
- module definitions are human-readable YAML
- wiring assumptions and pin maps are documented
- contributors can add, replace, or fork module types without rewriting the app

RetroSmart is closer to an Arduino-style platform than a sealed smart-home appliance. It is meant to be read, changed, flashed, and adapted for local hardware.

License: [GPL-3.0](./LICENSE)

## What RetroSmart Is

RetroSmart has two main parts:

- an iPhone app built with SwiftUI, SwiftData, and CoreBluetooth
- ESP32 module firmware built with Arduino libraries

Each module has its own:

- BLE identity
- firmware behavior
- YAML type definition
- app-rendered device page

That makes a module more than a generic ESP32 peripheral. It is a device contract with identity, capabilities, readings, actions, UI layout, pinout, and firmware requirements.

## Current Status

This repository is a working prototype baseline. It is usable for demonstrations, local experiments, and module development, but it is not a production smart-home platform.

Already implemented:

- multi-device iPhone app
- BLE discovery and onboarding
- persistent local device library
- config-driven device pages
- importable YAML module types
- foreground-only automations
- time-of-day automation triggers
- manual automation execution from the automations list
- sensor display on/off automation actions
- timed motor automation stop behavior in the app
- working sensor and actuator firmware sketches
- optional SSD1306 OLED support on sensor modules

Still prototype-grade:

- automations run only while the app is foregrounded
- BLE scaling beyond the documented target is not hardened
- YAML support is intentionally narrow
- firmware does not include OTA, cloud sync, or hardened security
- hardware is documented as wiring profiles and module pin maps, not full PCB/CAD releases

## Repository Layout

- [RetroSmart](./RetroSmart)
  iOS app project, source, resources, and app-specific notes
- [firmware](./firmware)
  Arduino module sketches plus shared firmware helpers
- [docs](./docs)
  PRD, setup manuals, architecture notes, authoring guide, compatibility notes, and contribution guidance
- [Legacy Code](./Legacy%20Code)
  earlier experiments kept for reference

## Built-In Module Types

- `dc_motor_drv8833_v1`
- `servo_180_v1`
- `temperature_ds18b20_v1`
- `air_quality_sgp40_v1`

## How It Works

RetroSmart treats YAML as the inspectable definition layer between app UI and firmware behavior.

At runtime:

1. The app loads built-in and imported YAML type definitions.
2. BLE modules identify themselves and expose capabilities.
3. The app renders controls and readings from the module definition.
4. Firmware publishes readings and accepts action commands over a fixed JSON-over-BLE contract.

This keeps the project pragmatic:

- new modules can be added without rebuilding the whole app architecture
- firmware and UI stay explainable
- users can inspect the active config behind each device

## Current Hardware Profile

The current prototype board target is `ESP32-S3 Zero`, intentionally constrained to `GPIO1` through `GPIO13`.

Board profile notes:

- `GPIO13` is used as an optional external status LED
- `GPIO21` onboard RGB is intentionally unused
- `GPIO0` is avoided because it is the BOOT pin

Current built-in pin maps:

- DC motor: `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional status LED `GPIO13`
- Servo: `GPIO7` signal, optional status LED `GPIO13`
- Temperature: `GPIO6` OneWire, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`
- Air quality: `GPIO5` SGP40 SDA, `GPIO6` SGP40 SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`

See [Hardware Notes](./docs/Hardware-Notes.md) for wiring, power, and power-bank guidance.

## Getting Started

Start here:

- [Getting Started](./docs/Getting-Started.md)
- [System Architecture](./docs/System-Architecture.md)
- [Module Authoring Guide](./docs/Module-Authoring-Guide.md)
- [Compatibility Matrix](./docs/Compatibility-Matrix.md)
- [Validation Checklist](./docs/Validation-Checklist.md)
- [Contributing Guide](./docs/Contributing-Guide.md)
- [Product Requirements](./docs/RetroSmart-PRD.md)

## Community And Safety

- [Contributing](./CONTRIBUTING.md)
- [Support](./SUPPORT.md)
- [Security Policy](./SECURITY.md)

## Useful Commands

Build the iOS app for simulator:

```sh
xcodebuild -project RetroSmart/RetroSmart.xcodeproj \
  -scheme RetroSmart \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/RetroSmartDerivedData \
  build
```

Build a smoother phone demo by using a Release run configuration or an Xcode archive. See [Validation Checklist](./docs/Validation-Checklist.md) for the recommended demo gate.

## Open Hardware Status

The repo currently exposes:

- firmware
- configs
- module pin maps
- wiring assumptions
- usage manuals

It does not yet include a full hardware release pack such as PCB files, schematics, enclosure files, or BOMs. Treat the documented hardware profile as a prototype wiring baseline rather than a complete manufacturable hardware package.
