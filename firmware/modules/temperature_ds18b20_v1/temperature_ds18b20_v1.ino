#include <DallasTemperature.h>
#include <OneWire.h>

#include "../../shared/RetroSmartBLEModule.h"

static constexpr int PIN_ONEWIRE = 7;
// ESP32-S3 Zero uses GPIO21 for the onboard WS2812, but this project keeps the
// module wiring inside GPIO1-GPIO13. Use GPIO13 for an optional external LED.
static constexpr int PIN_STATUS_LED = 13;

static RetroSmartBLEModule* gBleModule = nullptr;
static OneWire gOneWire(PIN_ONEWIRE);
static DallasTemperature gTemperatureSensor(&gOneWire);
static float gLastTemperatureC = NAN;
static uint32_t gLastReadMs = 0;

static void notifyTemperature() {
  JsonDocument state;
  state["readings"]["temperature_c"] = isnan(gLastTemperatureC) ? 0.0f : gLastTemperatureC;
  state["status"]["connected"] = gBleModule->isConnected();
  gBleModule->notifyState(state);
}

static void readTemperature() {
  gTemperatureSensor.requestTemperatures();
  float reading = gTemperatureSensor.getTempCByIndex(0);
  if (reading > -100.0f && reading < 150.0f) {
    gLastTemperatureC = reading;
    digitalWrite(PIN_STATUS_LED, HIGH);
    retroSmartLog("Temperature reading -> " + String(gLastTemperatureC, 2) + " C");
  } else {
    gLastTemperatureC = NAN;
    digitalWrite(PIN_STATUS_LED, LOW);
    retroSmartLog("Temperature read invalid");
  }
}

static void handleCommand(const JsonDocument& command) {
  // Temperature modules are read-only in v1.
}

void setup() {
  Serial.begin(115200);
  delay(250);
  retroSmartLog("Starting temperature module setup");
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);
  gTemperatureSensor.begin();

  RetroSmartIdentity identity = {
    .deviceId = retroSmartDeviceId("RS-TMP"),
    .deviceType = "temperature_ds18b20_v1",
    .model = "Temperature Module",
    .firmwareVersion = "0.1.0"
  };

  const char* const readings[] = {"temperature_c"};

  gBleModule = new RetroSmartBLEModule(
    "RetroSmartTemperature",
    identity,
    retroSmartCapabilitiesJson(identity.deviceType, nullptr, 0, readings, 1),
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
