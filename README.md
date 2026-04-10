# RetroSmart

RetroSmart is a modular smart-home retrofit prototype built around an iPhone app and dedicated ESP32-based modules. Each module has its own BLE identity, firmware behavior, and YAML type definition, while the app provides discovery, onboarding, persistent device management, config-driven UI, and simple foreground automations.

The current product source of truth is the persisted PRD at [docs/RetroSmart-PRD.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/RetroSmart-PRD.md).

## Current prototype scope

- SwiftUI iPhone app with `Devices`, `Automations`, and `RetroSmart AI` tabs
- SwiftData persistence for devices, imported module definitions, and automation rules
- CoreBluetooth-based BLE discovery and control for RetroSmart modules
- Built-in YAML configs and Arduino firmware for four initial module types
- Config-driven device pages and editable device settings
- Foreground-only "if this then that" style automations

## Repository layout

- [RetroSmart](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart)
  iOS app project, source, assets, and app-specific documentation
- [docs](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs)
  persisted PRD and planning documents
- [firmware](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware)
  shared firmware scaffolding, templates, and module sketches
- [Legacy Code](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/Legacy%20Code)
  older prototype sketches kept for reference

## Included module types

- `dc_motor_drv8833_v1`
- `servo_180_v1`
- `temperature_ds18b20_v1`
- `air_quality_sgp40_v1`

## Hardware profile

The current ESP32-S3 Zero profile is intentionally constrained to `GPIO1-GPIO13`.

- `GPIO13` is reserved as an optional external status LED
- `GPIO21` onboard RGB is intentionally unused
- `GPIO0` is avoided because it is the BOOT pin

## App highlights

- Nearby-device scanner hides already paired devices
- Discovery prefers live device identity over stale cached peripheral names after reflashing
- Devices screen uses a simplified two-column card grid
- Technical and debug details are moved into secondary disclosure sections

## Run the app

1. Open [RetroSmart.xcodeproj](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart/RetroSmart.xcodeproj) in Xcode.
2. Select an iOS 17+ simulator or device.
3. Build and run the `RetroSmart` target.

More app-specific detail lives in [RetroSmart/README.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart/README.md).

## Flash firmware

Firmware sketches live under [firmware/modules](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules).

For the current board profile:

- DC motor: `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional status LED `GPIO13`
- Servo: `GPIO7` signal, optional status LED `GPIO13`
- Temperature: `GPIO6` OneWire, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`
- Air quality: `GPIO5` SDA, `GPIO6` SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional status LED `GPIO13`

## Current limitations

- Automations run only while the app is foregrounded
- YAML parsing is intentionally scoped to the prototype schema
- BLE reconnection logic is suitable for prototyping, not production-grade pairing
- Firmware does not include OTA, cloud sync, or hardened security
