# Compatibility Matrix

This matrix records the current tested and intended compatibility for the prototype baseline.

## App

| Area | Current baseline |
| --- | --- |
| Platform | iPhone app |
| Minimum iOS target | iOS 17 |
| UI framework | SwiftUI |
| Persistence | SwiftData |
| BLE stack | CoreBluetooth |
| Build project | `RetroSmart/RetroSmart.xcodeproj` |
| Scheme | `RetroSmart` |

## Firmware Platform

| Area | Current baseline |
| --- | --- |
| Board profile | `ESP32-S3 Zero` |
| Firmware framework | Arduino ESP32 |
| Transport | BLE |
| Payload format | UTF-8 JSON over BLE characteristics |
| Serial monitor | `115200` baud |

## Built-In Modules

| Module type | Firmware sketch | Primary behavior | Automation triggers | Automation actions |
| --- | --- | --- | --- | --- |
| `dc_motor_drv8833_v1` | `firmware/modules/dc_motor_drv8833_v1/dc_motor_drv8833_v1.ino` | DRV8833 bidirectional motor control | none | `motor_run_forward`, `motor_run_reverse`, `motor_stop` |
| `servo_180_v1` | `firmware/modules/servo_180_v1/servo_180_v1.ino` | Hobby servo angle control | none | `set_servo_angle` |
| `temperature_ds18b20_v1` | `firmware/modules/temperature_ds18b20_v1/temperature_ds18b20_v1.ino` | DS18B20 temperature reading with optional OLED | `temperature_c` | `set_display_enabled` |
| `air_quality_sgp40_v1` | `firmware/modules/air_quality_sgp40_v1/air_quality_sgp40_v1.ino` | SGP40 VOC index and derived quality score with optional OLED | `quality_score`, `voc_index`, `air_quality_label` | `set_display_enabled` |

## Arduino Libraries

| Module | Libraries |
| --- | --- |
| DC motor | `BLEDevice`, `ArduinoJson` |
| Servo | `BLEDevice`, `ArduinoJson`, `ESP32Servo` |
| Temperature | `BLEDevice`, `ArduinoJson`, `OneWire`, `DallasTemperature`, `Wire`, `Adafruit_GFX`, `Adafruit_SSD1306` |
| Air quality | `BLEDevice`, `ArduinoJson`, `Wire`, `Adafruit_SGP40`, `Adafruit_GFX`, `Adafruit_SSD1306` |

The BLE headers are part of the ESP32 Arduino stack. Library names above match the firmware sketches and YAML metadata.

## Pin Profile

| Module | Pins |
| --- | --- |
| DC motor | `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional `GPIO13` status LED |
| Servo | `GPIO7` signal, optional `GPIO13` status LED |
| Temperature | `GPIO6` OneWire, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED |
| Air quality | `GPIO5` SGP40 SDA, `GPIO6` SGP40 SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED |

Board assumptions:

- use `GPIO1` through `GPIO13` where possible
- avoid `GPIO0`
- do not rely on onboard `GPIO21` RGB

## Automation Compatibility

Current automation support is intentionally narrow:

- one trigger
- one action
- foreground app execution only
- reading comparisons: above, below, equals
- time-of-day trigger while app is foregrounded
- action payload types: none, integer, float/double, boolean, string/enum
- app-side timed stop for motor forward/reverse automation actions

The app does not run automations after iOS suspends it.

## Verification Baseline

Known app verification command:

```sh
xcodebuild -project RetroSmart/RetroSmart.xcodeproj \
  -scheme RetroSmart \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/RetroSmartDerivedData \
  build
```

Firmware compile verification depends on a local Arduino workflow. This environment has not included `arduino-cli`, so firmware changes must be compiled in Arduino IDE or another configured ESP32 Arduino toolchain.
