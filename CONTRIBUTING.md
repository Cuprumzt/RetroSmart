# Contributing To RetroSmart

Thanks for improving RetroSmart. This project spans an iPhone app, ESP32 firmware, YAML module definitions, and prototype hardware notes, so changes should stay inspectable across those layers.

Start with the full [Contributing Guide](./docs/Contributing-Guide.md).

## Quick Rules

- Keep changes small enough to review.
- Keep YAML ids, BLE ids, action ids, and reading ids stable unless the change is intentional.
- Update docs when behavior, wiring, BLE payloads, configs, or app flows change.
- State whether the iOS app and firmware were built or why they could not be built.
- Do not commit local paths, private credentials, generated archives, or device-specific Xcode state.

## Useful Checks

```sh
xcodebuild -project RetroSmart/RetroSmart.xcodeproj \
  -scheme RetroSmart \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/RetroSmartDerivedData \
  build
```

For firmware changes, compile the affected sketch in Arduino IDE or an ESP32 Arduino CLI workflow. See the [Validation Checklist](./docs/Validation-Checklist.md).
