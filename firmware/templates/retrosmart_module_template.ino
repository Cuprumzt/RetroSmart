#include "../shared/RetroSmartBLEModule.h"

// Generic RetroSmart module sketch template.
// Replace the identity, capabilities, pin mapping, and state loop with the
// module-specific behavior for a new device type that still follows the v1
// JSON-over-BLE contract.
//
// ESP32-S3 Zero note:
// Keep prototype module wiring on GPIO1-GPIO13. Avoid relying on GPIO21 unless
// you intentionally drive the onboard WS2812, and avoid GPIO0 for normal I/O
// because it is tied to BOOT mode entry on this board.

static RetroSmartBLEModule* gBleModule = nullptr;

static void handleCommand(const JsonDocument& command) {
  const char* action = command["action"] | "";
  Serial.print("Received action: ");
  Serial.println(action);
}

void setup() {
  Serial.begin(115200);

  RetroSmartIdentity identity = {
    .deviceId = retroSmartDeviceId("RS-TPL"),
    .deviceType = "template_type_v1",
    .model = "RetroSmart Template Module",
    .firmwareVersion = "0.1.0"
  };

  const char* const actions[] = {"template_action"};
  const char* const readings[] = {"template_reading"};
  gBleModule = new RetroSmartBLEModule(
    "RetroSmartTemplate",
    identity,
    retroSmartCapabilitiesJson(identity.deviceType, actions, 1, readings, 1),
    handleCommand
  );
  gBleModule->begin();
}

void loop() {
  static uint32_t lastStateMs = 0;
  if (millis() - lastStateMs >= 1000) {
    lastStateMs = millis();
    JsonDocument state;
    state["readings"]["template_reading"] = 0;
    state["status"]["connection_hint"] = gBleModule->isConnected() ? "connected" : "idle";
    gBleModule->notifyState(state);
  }
}
