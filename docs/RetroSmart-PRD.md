# RetroSmart Product Requirements Document

## 1. Document control

- Product: RetroSmart iPhone app + ESP32 device ecosystem
- Original version: v1.0
- Current version: v1.1 prototype-aligned
- Status: Working prototype baseline
- Original author: Tong Zhang
- Original date: 31 March 2026
- Updated date: 1 April 2026

This Markdown file is the persisted project PRD for the current prototype. It is based on the original draft and updated to reflect implementation decisions made during the first working build.

## 2. Product overview

RetroSmart is a modular smart-home retrofit platform that turns existing appliances and sensing points into app-controlled devices using dedicated ESP32-based modules and a companion iPhone app.

Each module has:

- its own ESP32 board
- its own firmware
- its own BLE identity
- module-specific behavior

The app is the user-facing control layer for:

- discovering nearby devices
- adding them to a persistent home setup
- controlling them individually
- rendering device pages from config
- creating simple cross-device automations

This phase establishes:

- a robust device model for multiple simultaneously known modules
- a clear iPhone information architecture
- a readable and editable YAML device definition format
- a practical path from config to firmware and UI
- an initial set of working module types for prototyping

RetroSmart AI remains a placeholder for future AI-assisted adaptor and firmware workflows.

## 3. Problem statement

Most smart-home systems assume new infrastructure or appliance replacement. RetroSmart instead augments existing appliances and environments with external modules.

As the system grows beyond a single prototype, two problems emerge:

1. Device management complexity. Users need to discover, identify, name, customize, reconnect, and control multiple modules at once.
2. System scalability complexity. Each new module type needs a repeatable way to define firmware behavior, hardware pinout, app UI, settings, and automation compatibility.

The product must therefore provide both:

- a usable multi-device consumer experience
- a structured technical foundation for adding new module types

## 4. Product vision

Create a modular, extensible retrofit ecosystem where dedicated ESP32 modules identify themselves to the app, can be controlled in parallel, remain visible in the household even when offline, and can be defined through configuration files that are understandable to humans and usable by software.

## 5. Goals

### 5.1 Primary goals

- Enable one user to add, manage, and control multiple RetroSmart devices from one iPhone app.
- Allow each ESP32 module to identify its own device type to the app.
- Create a persistent device library in the app that remains visible whether devices are connected or disconnected.
- Support module-specific device pages and settings pages.
- Define a YAML-based configuration format that is:
  - easy to read and edit on a computer
  - importable into the app
  - expressive enough to describe UI, capabilities, and pinout
  - translatable into ESP32 Arduino firmware templates
- Support simple foreground-only "if this then that" automations using available readings and actions.

### 5.2 Secondary goals

- Let users customize device name and icon.
- Let users override or change device type after onboarding.
- Make the configuration visible inside device settings so the system remains inspectable and transparent.
- Leave a clear architectural placeholder for future AI workflows.

## 6. Non-goals for this phase

- Cloud sync
- Remote access outside local BLE range
- Multi-user household accounts
- Background automation execution
- Advanced automation logic such as nested conditions, timers, scenes, variables, or scripting
- Full AI-based adaptor generation or code generation implementation
- OTA firmware update system
- Android app
- Matter, HomeKit, Alexa, or Google Home integration
- Production-grade security hardening beyond sensible prototype-level local behavior

## 7. Target users

### 7.1 Primary user

A technically curious maker or early adopter who is comfortable setting up ESP32-based modules, using an iPhone app, and experimenting with retrofit automation.

### 7.2 Secondary user

A less technical household user who can operate previously added devices, rename them, assign icons, and build basic automations through a guided UI.

### 7.3 Future user

A creator who develops new RetroSmart module types by editing YAML config files, defining pinouts, and producing matching firmware and adaptors.

## 8. Core product principles

1. Dedicated device identity over generic hardware abstraction
2. Persistent household devices over transient BLE sessions
3. Configuration-driven extensibility over hardcoded expansion
4. Transparent system definition over hidden logic
5. Simple automations over powerful but opaque logic
6. Prototype reliability and inspectability over framework cleverness

## 9. Product scope

The current phase includes:

- iPhone app with 3-tab bottom navigation
- BLE-based multi-device onboarding and control
- persistent local device registry
- per-device detail page
- per-device settings page
- configuration import from Files app and pasted YAML
- simple automation builder
- module type definitions for 4 initial modules
- a config schema that drives both app behavior and firmware templates

## 10. User experience overview

### 10.1 Navigation structure

The app uses a bottom tab bar with three tabs:

1. Devices
2. Automations
3. RetroSmart AI

### 10.2 Devices tab

The Devices tab is the operational home screen.

It shows:

- all previously added devices
- a two-column grid of rounded device cards
- device icon
- custom device name
- primary live reading for connected sensor modules
- a compact disconnected state icon when a device is not connected
- a plus button with an add/import menu

Behavior:

- Connected sensor modules show their primary reading directly on the main card.
- Connected main cards do not show a green positive status badge.
- When a device is not connected, the reading area is replaced by a warning-style status icon.
- Technical and debug information should not dominate the main UI.

### 10.3 Add flow

The plus button opens a menu with:

- Add nearby device
- Import config from file
- Paste YAML config
- Manage module types

The menu should be anchored to the button rather than using a detached custom popup.

### 10.4 Device detail page

Tapping a device opens its dedicated device page.

This page shows:

- module-specific controls and readings
- connection status
- relevant action widgets or reading widgets based on device type
- a settings entry point

Technical details and debug surfaces should be hidden behind secondary disclosure sections instead of being shown by default.

### 10.5 Device settings page

The settings page allows the user to:

- change device name
- change device icon
- change device type
- view the active configuration
- inspect pinout and module metadata
- remove the device

### 10.6 Automations tab

The Automations tab allows users to create simple rules in the format:

`If [reading / event / state] then [action].`

### 10.7 RetroSmart AI tab

This tab is a placeholder for future AI-assisted workflows.

For this phase it should communicate future intent, such as:

- create adaptor with AI
- generate module program with AI
- upload reference photos and dimensions in future versions

No functional implementation is required beyond placeholder content.

## 11. Functional requirements

### 11.1 Device identity and connection model

- FR-1 Device self-identification: each ESP32 module must advertise the RetroSmart BLE service and identify its device type.
- FR-2 Unique instance identity: each physical module must expose a unique device ID.
- FR-3 Multi-device support: the app must support multiple known devices and attempt to connect to several while active.
- FR-4 Persistent registration: once added, a device remains in the Devices tab even when powered off or out of range.
- FR-5 Reconnection behavior: the app should attempt to reconnect known devices when they come into range.
- FR-6 Offline visibility: disconnected devices must still show last known metadata and offline state.

### 11.2 Device onboarding

- FR-7 Add device entry point: the Devices tab includes a plus icon.
- FR-8 Plus menu options: at minimum:
  - Add nearby device
  - Import config from file
  - Paste YAML config
- FR-9 BLE discovery flow: the app scans for compatible RetroSmart modules and lists nearby unpaired devices.
- FR-10 Type prefill from device: onboarding reads the live identity JSON and pre-fills assigned type.
- FR-11 User naming: during or after onboarding, the user can assign a custom name.
- FR-12 User icon selection: during or after onboarding, the user can choose a custom icon.
- FR-13 Type override: the user can change the device type even after the ESP has identified itself.
- FR-14 Local persistence: added devices and imported configs must be stored locally on the phone.
- FR-15 Paired device filtering: already-paired devices must not appear in the nearby onboarding list.
- FR-16 Reflash safety: if firmware on the same board changes module type, the onboarding flow should prefer live advertised or queried identity over cached peripheral labels.

### 11.3 Devices tab behavior

- FR-17 Device cards: each added device displays as a compact card with icon, name, and either a primary reading or disconnected-state icon.
- FR-18 Sort order: stable insertion order is acceptable for this phase.
- FR-19 Connection presentation: the main page should stay visually minimal and avoid redundant status text.

### 11.4 Device pages

- FR-20 Dynamic page rendering: each device page renders according to its selected device type config.
- FR-21 Available actions and readings: the page must expose only the actions and readings supported by that module type.
- FR-22 Settings access: each device page must include a settings entry point.
- FR-23 Detail status language: device pages use explicit human-readable status text such as `Connected` or `Disconnected`.

### 11.5 Device settings

- FR-24 Editable metadata: users can edit device name and icon.
- FR-25 Editable device type: users can change the assigned type from available built-in or imported types.
- FR-26 View configuration: users can read the configuration associated with the assigned type.
- FR-27 View pinout: pinout information must be visible in a human-readable format.
- FR-28 Mismatch warning: if assigned type differs from advertised type, the app must warn clearly.

### 11.6 Configuration import and management

- FR-29 Human-editable config format: YAML is the authoring format.
- FR-30 App import: users must be able to import a config file via Files app and raw YAML paste.
- FR-31 Validation: the app must validate imported configurations and reject malformed files with readable errors.
- FR-32 Built-in and imported types: the system supports both.
- FR-33 Type registry: imported configs appear in the selectable device-type list.
- FR-34 Global replacement: importing a config with the same `type_id` replaces the definition globally.
- FR-35 Delete protection: a config cannot be deleted while any device is assigned to it.

### 11.7 Automations

- FR-36 Automation list: the Automations tab displays existing rules and a way to create new ones.
- FR-37 Rule structure:
  - trigger device
  - trigger reading or state
  - operator and comparison value if needed
  - target device
  - target action and payload
- FR-38 Supported trigger sources: triggers may come from readings or state changes.
- FR-39 Supported action targets: actions may target actuator-capable devices.
- FR-40 Simple condition model: only single-condition single-action rules are supported.
- FR-41 Enable or disable rules: each automation must be toggleable.
- FR-42 Local execution: automations run only while the app is active in the foreground.
- FR-43 Device removal cleanup: removing a device also removes automations that reference it.

### 11.8 RetroSmart AI placeholder

- FR-44 Placeholder page: the RetroSmart AI tab must exist and present future-facing modules.
- FR-45 No active generation required: no backend or AI generation flow is required in this phase.

## 12. Initial supported module types

The first release includes the following module types.

### 12.1 DC motor module

- Type ID: `dc_motor_drv8833_v1`
- Purpose: bi-directional actuation using DRV8833
- UI: two press-and-hold directional buttons with motor state centered below
- Behavior:
  - hold `Forward` to actuate one direction
  - hold `Reverse` to actuate the other direction
  - release stops actuation
  - fixed speed
  - stops if the BLE connection drops while running

### 12.2 180-degree servo module

- Type ID: `servo_180_v1`
- Purpose: positional control using a hobby servo
- UI: slider
- Behavior:
  - user drags slider from 0 to 180 degrees
  - firmware clamps to 5 to 175 degrees
  - default startup angle is 5 degrees

### 12.3 Temperature sensing module

- Type ID: `temperature_ds18b20_v1`
- Purpose: temperature readout using DS18B20
- UI:
  - current temperature display
  - OLED display toggle when a connected module reports an attached SSD1306 display
- Behavior:
  - reads and publishes every 1 second
  - optional 96x16 SSD1306 OLED on a separate I2C bus shows thermometer icon plus temperature in one line

### 12.4 Air quality module

- Type ID: `air_quality_sgp40_v1`
- Purpose: air quality sensing using SGP40 over I2C
- UI:
  - primary 0-100 quality score
  - numeric VOC index
  - category label
  - OLED display toggle when a connected module reports an attached SSD1306 display
- Behavior:
  - reads and publishes every 1 second
  - uses fixed 25 C / 50% RH compensation defaults in firmware
  - optional 96x16 SSD1306 OLED on a separate I2C bus shows cloud icon plus Good/Poor score in one line

## 13. Configuration file format

### 13.1 Format choice

YAML is the source-of-truth authoring format.

Why:

- easy to read and edit by humans
- more legible than JSON for nested definitions
- easy to import into the app
- suitable for firmware template metadata
- supports comments

### 13.2 Top-level schema

All module configs include:

- `schema_version`
- `module`
- `identity`
- `ui`
- `capabilities`
- `automation`
- `hardware`
- `firmware`

### 13.3 Configuration design goals

The config should define:

- device type identity
- display metadata
- BLE communication contract hints
- supported readings
- supported actions
- UI structure for the device page
- editable settings fields
- pinout
- firmware generation hints
- automation compatibility

## 14. Device communication model

### 14.1 BLE model

Chosen approach for v1: JSON over BLE.

Each module exposes a standard RetroSmart BLE contract using UTF-8 JSON payloads.

Characteristics:

- Identity characteristic
- Capabilities characteristic
- State/readings characteristic
- Command characteristic

### 14.2 Characteristic behavior

- Identity: read on connect
- Capabilities: read on connect or after type/config change
- State/readings: notify once per second for sensors; notify on state change for actuators when useful
- Command: JSON writes

The app should rely primarily on notify updates rather than continuous polling.

### 14.3 Identity payload

At minimum:

```json
{
  "device_id": "RS-DCM-001A92",
  "device_type": "dc_motor_drv8833_v1",
  "model": "DC Motor Module",
  "fw_version": "0.1.0"
}
```

## 15. Automation model

### 15.1 Supported trigger types in v1

- reading above threshold
- reading below threshold
- reading equals value
- reading equals category
- device connected or disconnected is optional and secondary

### 15.2 Supported action types in v1

- run motor forward
- run motor reverse
- stop motor
- set servo angle

### 15.3 Limitations

- only one trigger per rule
- only one action per rule
- no AND or OR conditions
- no scheduling layer
- no history engine
- no background execution

## 16. Information architecture

### 16.1 Devices flow

Devices tab  
→ tap plus  
→ add nearby device or import config  
→ select device  
→ confirm type, name, and icon  
→ save  
→ device appears persistently in the grid

### 16.2 Device flow

Devices tab  
→ tap device card  
→ device page  
→ tap settings  
→ edit metadata, type, inspect config, or remove device

### 16.3 Automation flow

Automations tab  
→ add automation  
→ select trigger device  
→ select trigger reading and condition  
→ select target device  
→ select target action  
→ save rule

### 16.4 Config import flow

The plus menu supports:

- Import from Files app
- Paste raw YAML

The app also ships with built-in default configs for the standard module set.

## 17. Technical architecture requirements

### 17.1 App architecture

The app is structured around:

- persistent local device registry
- BLE connection manager supporting concurrent peripherals
- device-type registry loaded from built-in and imported YAML configs
- lightweight dynamic UI renderer
- automation engine using capabilities defined in config

### 17.2 Firmware architecture

Firmware is template-based per module family, with a shared RetroSmart BLE layer and module-specific hardware logic.

Suggested layers:

1. BLE transport layer
2. Identity and capability layer
3. Command and state schema layer
4. Hardware driver layer
5. Module behavior loop

### 17.3 Config-to-firmware path

The config file is not expected to fully generate working firmware by itself in v1. Instead, it provides structured inputs for template-based firmware.

Approach:

- use YAML as authoritative device definition
- map `type_id` to an Arduino template
- use `hardware.pinout` and `capabilities` to fill template variables
- generate or validate matching firmware metadata

## 18. Board profile: ESP32-S3 Zero

The current hardware baseline for the prototype is `ESP32-S3 Zero`.

Board-specific constraints for this project:

- Only `GPIO1` to `GPIO13` are treated as easily usable module pins.
- The prototype must not rely on the board's onboard RGB LED on `GPIO21`.
- `GPIO0` should be avoided for normal module I/O because it is tied to BOOT mode entry.
- Native USB serial should be enabled for flashing and debugging.

### 18.1 Built-in pin profile

- DC motor:
  - `motor_pwm`: `GPIO7`
  - `motor_in1`: `GPIO8`
  - `motor_in2`: `GPIO9`
  - `status_led`: `GPIO13` optional external LED
- Servo:
  - `servo_signal`: `GPIO7`
  - `status_led`: `GPIO13` optional external LED
- Temperature:
  - `onewire_data`: `GPIO6`
  - `oled_i2c_sda`: `GPIO7`
  - `oled_i2c_scl`: `GPIO8`
  - `status_led`: `GPIO13` optional external LED
- Air quality:
  - `i2c_sda`: `GPIO5`
  - `i2c_scl`: `GPIO6`
  - `oled_i2c_sda`: `GPIO7`
  - `oled_i2c_scl`: `GPIO8`
  - `status_led`: `GPIO13` optional external LED

### 18.2 Wiring assumptions

- Motor and servo modules require external power for actuators.
- Sensor and actuator grounds must be shared with the ESP32-S3 Zero.
- The status LED is optional and should not be treated as a required functional dependency.

## 19. Non-functional requirements

- NFR-1 Usability: state and actions should be legible without requiring technical knowledge.
- NFR-2 Readability: configuration files should be understandable to a technically literate human.
- NFR-3 Extensibility: adding a new module type should require minimal app code changes when it fits existing widget primitives.
- NFR-4 Reliability: the app must handle disconnected devices gracefully and never remove them automatically.
- NFR-5 Safety: actuator actions should default to safe stop behavior on disconnect where possible.
- NFR-6 Transparency: users should be able to inspect what type a device is and how it is configured.
- NFR-7 Lightweight renderer: dynamic rendering should stay simple and bounded.
- NFR-8 UI discipline: technical details, debugging output, and troubleshooting guidance should live in secondary or collapsible surfaces rather than crowding the main UI.

## 20. Key design decisions

### 20.1 Why per-module ESP32s

This simplifies identity, firmware ownership, and module independence. It aligns the physical product with the app model: one device equals one module.

### 20.2 Why persistent device cards

Homes are persistent environments. A device should still exist in the household even when temporarily offline.

### 20.3 Why YAML config

It balances human readability with machine structure and is suitable for both creators and software.

### 20.4 Why dynamic UI from config

This avoids hardcoding every future module page and keeps the ecosystem extensible.

### 20.5 Why simple automation first

Simple IF-THEN rules are easier to explain, debug, and trust during early deployment.

### 20.6 Why a simplified main UI

The main app surfaces should prioritize clarity and control. Technical details remain available, but they should not crowd the primary device-management experience.

## 21. Risks and open issues

### 21.1 BLE concurrency limits

iOS BLE behavior with several simultaneously active peripherals may constrain responsiveness.

### 21.2 Dynamic UI scope creep

A fully generic renderer can become complex. Widget primitives should remain constrained.

### 21.3 Type override ambiguity

Users may assign any device any type. The app should:

- default to the advertised device type
- allow manual reassignment
- warn clearly on mismatch

### 21.4 Automation execution dependency

Automations execute only while the app is foregrounded. This must be communicated clearly.

### 21.5 Configuration compatibility

Imported configs may describe unsupported widgets or capabilities. Versioning and validation remain necessary.

### 21.6 Global config replacement risk

Re-importing a config with the same `type_id` replaces the definition globally and may change behavior across multiple assigned devices.

### 21.7 Board-level resource limits

The ESP32-S3 Zero pin budget is intentionally constrained in this project. Future modules may require alternate pin maps or a larger board profile.

## 22. Success criteria

This phase is successful if:

- a user can add at least 4 distinct RetroSmart module types in one app
- devices remain listed when disconnected
- 2 or more devices can be connected and controlled in the same session
- each device opens its correct page with the correct controls or readings
- settings allow name, icon, and type edits plus config inspection
- YAML config files can be imported and validated
- at least one simple automation can be created between a sensor module and an actuator module
- the prototype works within the ESP32-S3 Zero pin constraints documented here

## 23. MVP definition

The MVP for this phase includes:

- iPhone app with bottom nav: Devices, Automations, RetroSmart AI
- persistent Devices tab using a simplified two-column card layout
- BLE onboarding flow
- support for multiple added devices
- auto-connect attempt for all known devices while app is active
- target support for up to 8 known devices in the household list
- device pages for DC motor, servo, temperature, and air quality modules
- device settings page with config visibility and device removal
- YAML-based module definitions
- import flow for configs from Files app and raw YAML paste
- simple single-trigger single-action automations running in foreground only
- RetroSmart AI placeholder page
- ESP32 Arduino firmware templates and initial module sketches
- ESP32-S3 Zero-compatible built-in pin maps

## 24. Initial YAML modules to ship

The app ships with built-in YAML for:

- `dc_motor_drv8833_v1`
- `servo_180_v1`
- `temperature_ds18b20_v1`
- `air_quality_sgp40_v1`

These definitions are bundled into the app and may be globally replaced by later imports with matching `type_id`.

## 25. Future extensions

Future versions may add:

- richer widget sets
- local automation execution on a hub or module
- firmware flashing from config packs
- AI-assisted creation of configs and code
- adaptor and CAD metadata
- cloud backup and household sync
- broader board-profile support beyond ESP32-S3 Zero
