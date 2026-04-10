# Getting Started

## Purpose

This guide is for someone who wants to run RetroSmart as a reusable project, not just inspect the source.

It covers:

- repository layout
- iPhone app build
- firmware flashing
- first-device onboarding
- the current prototype constraints

## 1. What You Need

### iPhone app

- macOS with Xcode
- an iPhone or iOS simulator
- Bluetooth-capable test hardware if you want to control real modules

### Firmware

- Arduino IDE or compatible ESP32 Arduino workflow
- ESP32 board support installed
- one or more supported modules
- the libraries listed in each module YAML and sketch

## 2. Repo Layout

- [README.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/README.md)
  public project overview
- [docs/RetroSmart-PRD.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/RetroSmart-PRD.md)
  product and prototype source of truth
- [RetroSmart](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart)
  iOS app
- [firmware](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware)
  module firmware and shared helpers

## 3. Build The App

1. Open [RetroSmart.xcodeproj](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart/RetroSmart.xcodeproj) in Xcode.
2. Select the `RetroSmart` scheme.
3. Choose an iPhone simulator or a physical iPhone.
4. Build and run.

Main app surfaces:

- `Devices`
- `Automations`
- `RetroSmart AI`

## 4. Flash A Module

Module sketches live in [firmware/modules](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules).

Current built-in sketches:

- [dc_motor_drv8833_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules/dc_motor_drv8833_v1/dc_motor_drv8833_v1.ino)
- [servo_180_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules/servo_180_v1/servo_180_v1.ino)
- [temperature_ds18b20_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules/temperature_ds18b20_v1/temperature_ds18b20_v1.ino)
- [air_quality_sgp40_v1.ino](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/firmware/modules/air_quality_sgp40_v1/air_quality_sgp40_v1.ino)

General flashing flow:

1. Open the sketch for your target module.
2. Install the required Arduino libraries noted in the sketch and matching YAML config.
3. Select your ESP32 target.
4. For `ESP32-S3 Zero`, enable native USB serial if needed.
5. Flash the module.
6. Open serial monitor at `115200`.

## 5. Current ESP32-S3 Zero Pin Maps

- DC motor: `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional `GPIO13` status LED
- Servo: `GPIO7` servo signal, optional `GPIO13` status LED
- Temperature: `GPIO6` DS18B20 data, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED
- Air quality: `GPIO5` SGP40 SDA, `GPIO6` SGP40 SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED

Board profile assumptions:

- avoid `GPIO0`
- ignore onboard `GPIO21` RGB
- keep wiring within `GPIO1-GPIO13`

## 6. Add A Device In The App

1. Launch the app.
2. Open the `Devices` tab.
3. Use the top-right add menu.
4. Choose `Add nearby device`.
5. Select a discovered module.
6. Save it into the household list.

Imported module types can also be added through:

- `Import config from file`
- `Paste YAML config`

## 7. How The App Knows What To Render

Each module type has a YAML definition in:

- [RetroSmart/RetroSmart/Resources/BuiltInConfigs](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/RetroSmart/RetroSmart/Resources/BuiltInConfigs)

The app reads those configs and renders:

- readings
- buttons
- hold buttons
- sliders
- toggles
- settings visibility

## 8. Current Limits

- Automations run only while the app is foregrounded.
- BLE behavior is prototype-oriented.
- The YAML parser is intentionally limited to the current schema style.
- The project is meant to be adapted, but not all extension points are generalized yet.

## 9. Next Documents

- [docs/System-Architecture.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/System-Architecture.md)
- [docs/Module-Authoring-Guide.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/Module-Authoring-Guide.md)
- [docs/Contributing-Guide.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/Contributing-Guide.md)
