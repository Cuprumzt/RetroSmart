# Getting Started

This guide is for someone who wants to run RetroSmart as a reusable project, not just inspect the source.

It covers:

- repository layout
- iPhone app builds
- firmware flashing
- first-device onboarding
- prototype constraints

## 1. Requirements

For the iPhone app:

- macOS with Xcode
- an iPhone or iOS simulator
- Bluetooth-capable test hardware if you want to control real modules

For firmware:

- Arduino IDE or compatible ESP32 Arduino workflow
- ESP32 board support installed
- one or more supported modules
- the Arduino libraries listed in each module YAML and sketch

## 2. Repository Layout

- [README.md](../README.md)
  public project overview
- [RetroSmart](../RetroSmart)
  iOS app
- [firmware](../firmware)
  module firmware and shared helpers
- [docs/RetroSmart-PRD.md](./RetroSmart-PRD.md)
  product and prototype source of truth
- [docs/Compatibility-Matrix.md](./Compatibility-Matrix.md)
  current app, firmware, module, and library compatibility

## 3. Build The App

1. Open [RetroSmart.xcodeproj](../RetroSmart/RetroSmart.xcodeproj) in Xcode.
2. Select the `RetroSmart` scheme.
3. Choose an iPhone simulator or a physical iPhone.
4. Build and run.

Main app surfaces:

- `Devices`
- `Automations`
- `RetroSmart AI`

Command-line simulator build:

```sh
xcodebuild -project RetroSmart/RetroSmart.xcodeproj \
  -scheme RetroSmart \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/RetroSmartDerivedData \
  build
```

## 4. Build A Demo Version For Your Phone

For smoother demos, avoid running with the debugger attached.

Recommended Xcode run setup:

1. Select your iPhone as the destination.
2. Open `Product > Scheme > Edit Scheme...`.
3. Select `Run`.
4. Set `Build Configuration` to `Release`.
5. Uncheck `Debug executable`.
6. Run on the phone.

Archive setup:

1. Select `Any iOS Device`.
2. Run `Product > Archive`.
3. In Organizer, choose `Distribute App`.
4. Choose a development distribution build for your phone.

## 5. Flash A Module

Module sketches live in [firmware/modules](../firmware/modules).

Current built-in sketches:

- [dc_motor_drv8833_v1.ino](../firmware/modules/dc_motor_drv8833_v1/dc_motor_drv8833_v1.ino)
- [servo_180_v1.ino](../firmware/modules/servo_180_v1/servo_180_v1.ino)
- [temperature_ds18b20_v1.ino](../firmware/modules/temperature_ds18b20_v1/temperature_ds18b20_v1.ino)
- [air_quality_sgp40_v1.ino](../firmware/modules/air_quality_sgp40_v1/air_quality_sgp40_v1.ino)

General flashing flow:

1. Open the sketch for your target module.
2. Install the required Arduino libraries noted in the sketch and matching YAML config.
3. Select your ESP32 target.
4. For `ESP32-S3 Zero`, enable native USB serial if needed.
5. Flash the module.
6. Open serial monitor at `115200`.

## 6. ESP32-S3 Zero Pin Maps

- DC motor: `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional `GPIO13` status LED
- Servo: `GPIO7` servo signal, optional `GPIO13` status LED
- Temperature: `GPIO6` DS18B20 data, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED
- Air quality: `GPIO5` SGP40 SDA, `GPIO6` SGP40 SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED

Board profile assumptions:

- avoid `GPIO0`
- ignore onboard `GPIO21` RGB
- keep wiring within `GPIO1` through `GPIO13`

See [Hardware Notes](./Hardware-Notes.md) for wiring and power details.

## 7. Add A Device In The App

1. Launch the app.
2. Open the `Devices` tab.
3. Use the top-right add menu.
4. Choose `Add nearby device`.
5. Select a discovered module.
6. Save it into the household list.

Imported module types can also be added through:

- `Import config from file`
- `Paste YAML config`

## 8. Automations

Automations run locally while the app is active in the foreground.

Current trigger types:

- module readings above, below, or equal to a value
- time of day while the app is open

Current action types:

- motor forward/reverse/stop
- servo angle
- sensor OLED display on/off

Motor forward/reverse automations can store a run duration. The app sends a stop command after that duration as long as the app remains active and connected.

## 9. How The App Knows What To Render

Each module type has a YAML definition in [RetroSmart/Resources/BuiltInConfigs](../RetroSmart/RetroSmart/Resources/BuiltInConfigs).

The app reads those configs and renders:

- readings
- buttons
- hold buttons
- sliders
- toggles
- settings visibility

## 10. Current Limits

- Automations run only while the app is foregrounded.
- Time triggers are not iOS background schedules.
- BLE behavior is prototype-oriented.
- The YAML parser is intentionally limited to the current schema style.
- Power banks with aggressive low-current shutoff may need a hardware dummy load. See [Hardware Notes](./Hardware-Notes.md).

## 11. Next Documents

- [System Architecture](./System-Architecture.md)
- [Module Authoring Guide](./Module-Authoring-Guide.md)
- [Compatibility Matrix](./Compatibility-Matrix.md)
- [Validation Checklist](./Validation-Checklist.md)
- [Contributing Guide](./Contributing-Guide.md)
