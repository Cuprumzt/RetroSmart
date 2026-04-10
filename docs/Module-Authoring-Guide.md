# Module Authoring Guide

## Purpose

This guide is for people adding or adapting RetroSmart module types.

A module type in RetroSmart is made of three parts:

1. firmware sketch
2. YAML definition
3. app compatibility with the declared widget/capability set

## 1. Start With A Clear Module Contract

Before writing code, define:

- what the module does
- what readings it publishes
- what actions it accepts
- what pin map it needs
- what should appear on the device page

If the module is simple and inspectable, the rest of the stack stays simple.

## 2. Create The Firmware Sketch

Place new module firmware under:

- [firmware/modules](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules)

Follow the existing pattern:

- initialize hardware
- build a `RetroSmartIdentity`
- define action ids and reading ids
- construct `RetroSmartBLEModule`
- publish state regularly
- handle incoming commands by action id

Useful shared helpers:

- [firmware/shared/RetroSmartBLEModule.h](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/shared/RetroSmartBLEModule.h)
- [firmware/shared/AirQualityScore.h](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/shared/AirQualityScore.h)
- [firmware/shared/RetroSmartOLEDStatusDisplay.h](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/shared/RetroSmartOLEDStatusDisplay.h)

## 3. Create The YAML Definition

Built-in module YAML lives in:

- [RetroSmart/RetroSmart/Resources/BuiltInConfigs](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart/RetroSmart/Resources/BuiltInConfigs)

Current schema expects:

- `schema_version`
- `module`
- `identity`
- `ui`
- `capabilities`
- `automation`
- `hardware`
- `firmware`

Keep the YAML aligned with the firmware. If the firmware publishes `temperature_c`, the YAML must refer to `temperature_c`, not a renamed variation.

## 4. Use Supported Widget Primitives

Current app widget support is intentionally small:

- `section`
- `text`
- `status`
- `button`
- `hold_button`
- `slider`
- `reading`
- `toggle`

Do not assume the app supports arbitrary UI controls just because YAML is editable.

## 5. Add Conditional UI Carefully

The app now supports simple conditional visibility for widgets:

- `visible_when_source`
- `visible_when_equals`

Use this for practical state-dependent controls such as:

- only show a display toggle when `display_present == true`

Avoid complex multi-condition logic in YAML. That belongs in future schema work if needed.

## 6. Respect The BLE Contract

Action ids, reading ids, and status fields should stay:

- short
- stable
- explicit

Prefer:

- `set_display_enabled`
- `temperature_c`
- `motor_state`

Avoid:

- overloaded generic names
- changing ids casually after a module is already in use

## 7. Keep Hardware Definitions Honest

Document the real board assumptions in the YAML:

- interfaces
- pinout
- required libraries

If a module needs a special bus split or a second I2C bus, put that in the config and firmware together.

## 8. Current ESP32-S3 Zero Constraints

For this project profile:

- stay inside `GPIO1-GPIO13` where possible
- avoid `GPIO0`
- do not rely on onboard `GPIO21` RGB
- `GPIO13` is the optional external status LED

If your module cannot fit these constraints, either:

- define a new board profile, or
- explicitly document the exception

## 9. Add App Support Only When Needed

A new module should reuse the generic renderer by default.

Only extend app code if the module truly needs:

- a new widget type
- a special layout
- unusual state formatting

The current app already has pragmatic special cases for a few module-specific views. Treat those as exceptions, not the default module path.

## 10. Verification Checklist

Before calling a module done:

- firmware compiles
- BLE identity is correct
- actions and readings match YAML ids
- device card preview looks right
- device detail page renders cleanly
- settings page reflects the module type correctly
- removal and re-onboarding still work

## 11. When In Doubt

Use an existing module as a template:

- [temperature_ds18b20_v1.yaml](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart/RetroSmart/Resources/BuiltInConfigs/temperature_ds18b20_v1.yaml)
- [air_quality_sgp40_v1.yaml](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart/RetroSmart/Resources/BuiltInConfigs/air_quality_sgp40_v1.yaml)
- [temperature_ds18b20_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules/temperature_ds18b20_v1/temperature_ds18b20_v1.ino)
- [air_quality_sgp40_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules/air_quality_sgp40_v1/air_quality_sgp40_v1.ino)
