# Module Authoring Guide

This guide is for people adding or adapting RetroSmart module types.

A module type in RetroSmart is made of three parts:

1. firmware sketch
2. YAML definition
3. app compatibility with the declared widget and capability set

## 1. Start With A Clear Module Contract

Before writing code, define:

- what the module does
- what readings it publishes
- what actions it accepts
- what pin map it needs
- what should appear on the device page
- whether readings or actions should appear in automations

If the module contract is simple and inspectable, the rest of the stack stays simple.

## 2. Create The Firmware Sketch

Place new module firmware under [firmware/modules](../firmware/modules).

Follow the existing pattern:

- initialize hardware
- build a `RetroSmartIdentity`
- define action ids and reading ids
- construct `RetroSmartBLEModule`
- publish state regularly
- handle incoming commands by action id

Useful shared helpers:

- [RetroSmartBLEModule.h](../firmware/shared/RetroSmartBLEModule.h)
- [AirQualityScore.h](../firmware/shared/AirQualityScore.h)
- [RetroSmartOLEDStatusDisplay.h](../firmware/shared/RetroSmartOLEDStatusDisplay.h)

Use [retrosmart_module_template.ino](../firmware/templates/retrosmart_module_template.ino) as a starting point for a simple module.

## 3. Create The YAML Definition

Built-in module YAML lives in [RetroSmart/Resources/BuiltInConfigs](../RetroSmart/RetroSmart/Resources/BuiltInConfigs).

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

The app supports simple conditional visibility for widgets:

- `visible_when_source`
- `visible_when_equals`

Use this for practical state-dependent controls such as only showing a display toggle when `display_present == true`.

Avoid complex multi-condition logic in YAML. That belongs in future schema work if needed.

## 6. Declare Automation Compatibility

The `automation` block controls which capabilities are exposed to the automation editor.

Example:

```yaml
automation:
  triggers: [temperature_c]
  actions: [set_display_enabled]
```

Current app behavior:

- sensor readings can be trigger sources
- app time-of-day can also be a trigger source
- actuator actions can be targets
- sensor display toggles can be targets when declared
- motor forward/reverse actions can be given a run duration in the app

The app executes automations only while foregrounded.

## 7. Respect The BLE Contract

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

## 8. Keep Hardware Definitions Honest

Document the real board assumptions in YAML:

- interfaces
- pinout
- required libraries

If a module needs a special bus split or a second I2C bus, put that in the config and firmware together.

## 9. ESP32-S3 Zero Constraints

For this project profile:

- stay inside `GPIO1` through `GPIO13` where possible
- avoid `GPIO0`
- do not rely on onboard `GPIO21` RGB
- use `GPIO13` only as an optional external status LED

If your module cannot fit these constraints, either define a new board profile or explicitly document the exception.

## 10. Power And Safety Expectations

When adding actuator modules:

- use external actuator power where required
- share ground with the ESP32 board
- stop active motion when BLE disconnects if the actuator can remain dangerous
- avoid firmware keep-alive behavior that moves hardware unexpectedly

Some USB power banks shut down with low-current ESP32 modules. Use a hardware dummy load or a low-current-friendly power source rather than forced firmware motion. See [Hardware Notes](./Hardware-Notes.md).

## 11. Add App Support Only When Needed

A new module should reuse the generic renderer by default.

Only extend app code if the module truly needs:

- a new widget type
- a special layout
- unusual state formatting

The current app has pragmatic special cases for a few module-specific views. Treat those as exceptions, not the default module path.

## 12. Verification Checklist

Before calling a module done:

- firmware compiles
- BLE identity is correct
- actions and readings match YAML ids
- device card preview looks right
- device detail page renders cleanly
- settings page reflects the module type correctly
- automation eligibility matches the YAML
- removal and re-onboarding still work

## 13. When In Doubt

Use an existing module as a template:

- [temperature_ds18b20_v1.yaml](../RetroSmart/RetroSmart/Resources/BuiltInConfigs/temperature_ds18b20_v1.yaml)
- [air_quality_sgp40_v1.yaml](../RetroSmart/RetroSmart/Resources/BuiltInConfigs/air_quality_sgp40_v1.yaml)
- [temperature_ds18b20_v1.ino](../firmware/modules/temperature_ds18b20_v1/temperature_ds18b20_v1.ino)
- [air_quality_sgp40_v1.ino](../firmware/modules/air_quality_sgp40_v1/air_quality_sgp40_v1.ino)
