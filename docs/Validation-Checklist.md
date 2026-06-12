# Validation Checklist

Use this checklist before demos, releases, or broad refactors.

## App Build

Run the simulator build:

```sh
xcodebuild -project RetroSmart/RetroSmart.xcodeproj \
  -scheme RetroSmart \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/RetroSmartDerivedData \
  build
```

For a phone demo:

- use a `Release` run configuration
- uncheck `Debug executable`
- or install a development distribution build from an Xcode archive

## App Smoke Test

Check:

- app launches
- three tabs are visible: `Devices`, `Automations`, `RetroSmart AI`
- built-in module configs load
- add menu opens from the Devices tab
- config library opens
- YAML paste import rejects invalid YAML with a readable error
- automations list opens
- automation editor supports device and time trigger modes

## BLE Smoke Test

With hardware available, check:

- each flashed module advertises a RetroSmart name
- onboarding reads identity JSON
- duplicate already-added modules do not show as new nearby devices
- known devices reconnect while the app is foregrounded
- state/readings update on the device detail page
- commands write successfully from the app

## Firmware Smoke Test

For each module:

- firmware compiles in Arduino IDE or a configured ESP32 Arduino CLI workflow
- serial monitor opens at `115200`
- identity fields match the YAML `type_id`
- capability action ids match YAML
- capability reading ids match YAML
- status LED behavior is safe and understandable

Module-specific checks:

- DC motor stops on `motor_stop`
- DC motor stops if BLE disconnects while running
- Servo clamps target angle to the firmware-safe range
- Temperature publishes `temperature_c`, `display_present`, and `display_enabled`
- Air quality publishes `quality_score`, `voc_index`, `air_quality_label`, `display_present`, and `display_enabled`

## Documentation Gate

Before committing public-facing changes:

- all Markdown links are relative unless they intentionally point to an external site
- root README reflects current module set
- root `CONTRIBUTING.md`, `SUPPORT.md`, and `SECURITY.md` reflect current project maturity
- PRD reflects implemented automation behavior
- compatibility matrix reflects firmware libraries and pin maps
- hardware notes reflect any wiring or power changes
- no local absolute paths such as `/Users/...` appear in Markdown
