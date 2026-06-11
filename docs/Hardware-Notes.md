# Hardware Notes

RetroSmart currently documents a prototype wiring profile, not a complete manufacturable hardware release.

## Board Profile

The current baseline board is `ESP32-S3 Zero`.

Project assumptions:

- keep module wiring within `GPIO1` through `GPIO13`
- avoid `GPIO0` because it is tied to BOOT mode entry
- do not rely on the onboard `GPIO21` RGB LED
- use `GPIO13` only as an optional external status LED
- enable native USB serial when required by the selected Arduino board profile

## Power

Actuator modules need more power planning than sensor modules.

General rules:

- servo and motor power should come from a supply that can handle the actuator current
- sensor and actuator grounds must be shared with the ESP32
- avoid powering motors or servos only from a weak USB regulator
- add decoupling near actuators when motion causes resets or BLE drops

## USB Power Banks

Many USB power banks shut off when current draw is too low. ESP32 modules can fall below that threshold while idle.

Recommended fixes:

- use a power bank designed for low-current IoT devices
- use a USB keep-alive/load module
- add a dummy load across the `5V` rail and `GND`

Typical dummy-load starting points:

- `100 ohm`, at least `1W`: about `50mA` at `5V`
- `68 ohm`, at least `1W`, preferably `2W`: about `74mA` at `5V`

The resistor will get warm. Mount it where heat is safe and cannot contact plastic, paper, wires, or skin.

Firmware-based keep-alive behavior is not recommended as the primary fix because it can affect BLE responsiveness, move actuators unexpectedly, and still fail against higher power-bank thresholds.

## OLED Displays

Temperature and air quality modules support optional SSD1306 OLED display wiring on a separate I2C bus:

- OLED SDA: `GPIO7`
- OLED SCL: `GPIO8`

The firmware reports:

- `display_present`
- `display_enabled`

The app uses those readings to show a display toggle only when the module reports a present display.

## Module Pin Maps

| Module | Pin map |
| --- | --- |
| DC motor | `GPIO7` PWM, `GPIO8` IN1, `GPIO9` IN2, optional `GPIO13` status LED |
| Servo | `GPIO7` servo signal, optional `GPIO13` status LED |
| Temperature | `GPIO6` DS18B20 data, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED |
| Air quality | `GPIO5` SGP40 SDA, `GPIO6` SGP40 SCL, `GPIO7` OLED SDA, `GPIO8` OLED SCL, optional `GPIO13` status LED |

## Open Hardware Gap

The repository does not yet include:

- schematics
- PCB layout files
- enclosure files
- BOMs
- assembly drawings

Until those exist, treat RetroSmart as an open firmware/app/config platform with documented prototype wiring.
