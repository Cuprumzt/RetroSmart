# RetroSmart

RetroSmart is an open hardware and software retrofit platform for building modular smart-home devices around an iPhone app and ESP32-based modules.

The goal is not to hide the system behind a sealed product surface. The goal is to make the whole stack inspectable and adaptable:

- iPhone app source is in the repo
- module firmware is in the repo
- module definitions are human-readable YAML
- wiring assumptions and pin maps are documented
- contributors can add, replace, or fork module types without rewriting the whole app

In that sense, the project is closer to the spirit of Arduino and Linux than to a closed smart-home appliance. You are expected to read it, change it, and shape it for your own hardware.

The current license in this repository is [GPL-3.0](./LICENSE).

The product and prototype source of truth remains the PRD at [docs/RetroSmart-PRD.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/RetroSmart-PRD.md).

## What RetroSmart Is

RetroSmart is a local-first system with two main parts:

- an iPhone app built with SwiftUI, SwiftData, and CoreBluetooth
- a family of ESP32 modules running Arduino-based firmware

Each module has:

- its own BLE identity
- its own firmware behavior
- its own YAML type definition
- its own app-rendered device page

That means a module is not just "an ESP32 peripheral". It is a defined device contract with:

- identity
- capabilities
- live readings
- actions
- UI layout
- pinout
- firmware library requirements

## What Is In This Repository

- [RetroSmart](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart)
  iOS app project, source, resources, and app-specific notes
- [firmware](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware)
  Arduino module sketches plus shared firmware helpers
- [docs](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs)
  PRD, setup manuals, architecture notes, authoring guide, and contribution guidance
- [Legacy Code](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/Legacy%20Code)
  earlier experiments kept for reference

Current built-in module types:

- `dc_motor_drv8833_v1`
- `servo_180_v1`
- `temperature_ds18b20_v1`
- `air_quality_sgp40_v1`

## Why It Is Structured This Way

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

The current prototype board target is `ESP32-S3 Zero`, intentionally constrained to `GPIO1-GPIO13`.

Board profile notes:

- `GPIO13` is used as an optional external status LED
- `GPIO21` onboard RGB is intentionally unused
- `GPIO0` is avoided because it is the BOOT pin

Current built-in pin maps:

- DC motor: `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional status LED `GPIO13`
- Servo: `GPIO7` signal, optional status LED `GPIO13`
- Temperature: `GPIO6` OneWire, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`
- Air quality: `GPIO5` SGP40 SDA, `GPIO6` SGP40 SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`

## Repository Manuals

Start here if you want to use or adapt the project:

- [docs/Getting-Started.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/Getting-Started.md)
- [docs/System-Architecture.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/System-Architecture.md)
- [docs/Module-Authoring-Guide.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/Module-Authoring-Guide.md)
- [docs/Contributing-Guide.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/Contributing-Guide.md)
- [docs/RetroSmart-PRD.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/RetroSmart-PRD.md)

## Current Status

The repository is a working prototype, not a finished product.

What is already real:

- multi-device iPhone app
- BLE discovery and onboarding
- persistent device library
- config-driven device pages
- importable YAML module types
- foreground automations
- working sensor and actuator firmware sketches
- optional SSD1306 OLED support on sensor modules

What is still prototype-grade:

- automations run only while the app is foregrounded
- BLE scaling beyond the documented target is not hardened
- YAML support is intentionally narrow
- firmware is not built around OTA, cloud sync, or security hardening
- hardware is documented as wiring profiles and module pin maps, not as full PCB CAD releases

## If You Want To Adapt It

Good uses of this repo:

- build the app and flash the included modules as-is
- change pin maps for your own ESP32 board
- fork the YAML format for your own module catalog
- add new sensors or actuators by following the module authoring guide
- strip the app down to your own household-specific device set

Bad assumptions to make:

- that this is production-hardened
- that iOS BLE concurrency has already been solved for large deployments
- that the current YAML subset parser is a general YAML implementation

## Short Version

RetroSmart is an open, hackable smart-home retrofit stack:

- SwiftUI iPhone app
- Arduino ESP32 firmware
- YAML module definitions
- documented wiring profiles
- meant to be reused, forked, and adapted

If anything is unclear at the project level, the main open question is how far you want to take the "open hardware" part beyond firmware and wiring profiles.

Right now the repo clearly exposes:

- software
- firmware
- configs
- module pin maps
- usage manuals

What it does not yet expose as a first-class open-hardware deliverable is a full hardware pack such as:

- BOMs
- schematics
- PCB files
- enclosure files

If you want, I can add that structure to `docs` next so the repo reads more like a full public platform instead of a code-first prototype.
