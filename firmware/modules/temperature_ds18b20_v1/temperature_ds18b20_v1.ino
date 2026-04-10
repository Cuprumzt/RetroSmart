#include <DallasTemperature.h>
#include <OneWire.h>

#include "../../shared/RetroSmartBLEModule.h"
#include "../../shared/RetroSmartOLEDStatusDisplay.h"

static constexpr int PIN_ONEWIRE = 6;
static constexpr int PIN_DISPLAY_SDA = 7;
static constexpr int PIN_DISPLAY_SCL = 8;
// ESP32-S3 Zero uses GPIO21 for the onboard WS2812, but this project keeps the
// module wiring inside GPIO1-GPIO13. Use GPIO13 for an optional external LED.
static constexpr int PIN_STATUS_LED = 13;

static RetroSmartBLEModule* gBleModule = nullptr;
static TwoWire gDisplayWire = TwoWire(0);
static OneWire gOneWire(PIN_ONEWIRE);
static DallasTemperature gTemperatureSensor(&gOneWire);
static RetroSmartOLEDStatusDisplay gDisplay(&gDisplayWire);
static float gLastTemperatureC = NAN;
static uint32_t gLastReadMs = 0;

static void notifyTemperature() {
  JsonDocument state;
  state["readings"]["temperature_c"] = isnan(gLastTemperatureC) ? 0.0f : gLastTemperatureC;
  state["readings"]["display_present"] = gDisplay.isPresent();
  state["readings"]["display_enabled"] = gDisplay.isEnabled();
  state["status"]["connected"] = gBleModule->isConnected();
  gBleModule->notifyState(state);
}

static void readTemperature() {
  gTemperatureSensor.requestTemperatures();
  float reading = gTemperatureSensor.getTempCByIndex(0);
  if (reading > -100.0f && reading < 150.0f) {
    gLastTemperatureC = reading;
    digitalWrite(PIN_STATUS_LED, HIGH);
    gDisplay.showTemperature(gLastTemperatureC);
    retroSmartLog("Temperature reading -> " + String(gLastTemperatureC, 2) + " C");
  } else {
    gLastTemperatureC = NAN;
    digitalWrite(PIN_STATUS_LED, LOW);
    gDisplay.showTemperature(gLastTemperatureC);
    retroSmartLog("Temperature read invalid");
  }
}

static void handleCommand(const JsonDocument& command) {
  const char* action = command["action"] | "";
  if (strcmp(action, "set_display_enabled") != 0) {
    return;
  }

  const bool requestedEnabled = command["payload"]["value"] | true;
  gDisplay.setEnabled(requestedEnabled);
  if (gDisplay.isEnabled()) {
    gDisplay.showTemperature(gLastTemperatureC);
  }
  notifyTemperature();
}

void setup() {
  Serial.begin(115200);
  delay(250);
  retroSmartLog("Starting temperature module setup");
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);
  gTemperatureSensor.begin();
  gDisplay.begin(PIN_DISPLAY_SDA, PIN_DISPLAY_SCL);

  RetroSmartIdentity identity = {
    .deviceId = retroSmartDeviceId("RS-TMP"),
    .deviceType = "temperature_ds18b20_v1",
    .model = "Temperature Module",
    .firmwareVersion = "0.2.0"
  };

  const char* const actions[] = {"set_display_enabled"};
  const char* const readings[] = {"temperature_c", "display_present", "display_enabled"};

  gBleModule = new RetroSmartBLEModule(
    "RetroSmartTemperature",
    identity,
    retroSmartCapabilitiesJson(identity.deviceType, actions, 1, readings, 3),
    handleCommand
  );
  gBleModule->begin();
  retroSmartLog("Temperature module setup complete");
}

void loop() {
  if (millis() - gLastReadMs >= 1000) {
    gLastReadMs = millis();
    readTemperature();
    notifyTemperature();
  }
}
