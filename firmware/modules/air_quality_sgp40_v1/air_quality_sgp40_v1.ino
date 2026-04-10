#include <Adafruit_SGP40.h>
#include <Wire.h>

#include "../../shared/AirQualityScore.h"
#include "../../shared/RetroSmartBLEModule.h"
#include "../../shared/RetroSmartOLEDStatusDisplay.h"

static constexpr int PIN_I2C_SDA = 5;
static constexpr int PIN_I2C_SCL = 6;
static constexpr int PIN_DISPLAY_SDA = 7;
static constexpr int PIN_DISPLAY_SCL = 8;
// ESP32-S3 Zero uses GPIO21 for the onboard WS2812, but this project keeps the
// module wiring inside GPIO1-GPIO13. Use GPIO13 for an optional external LED.
static constexpr int PIN_STATUS_LED = 13;
static constexpr float DEFAULT_TEMPERATURE_C = 25.0f;
static constexpr float DEFAULT_HUMIDITY_RH = 50.0f;
static constexpr uint32_t READ_INTERVAL_MS = 1000;

static RetroSmartBLEModule* gBleModule = nullptr;
static TwoWire gSensorWire = TwoWire(0);
static TwoWire gDisplayWire = TwoWire(1);
static Adafruit_SGP40 gSgp40;
static RetroSmartOLEDStatusDisplay gDisplay(&gDisplayWire);

static bool gSensorReady = false;
static int gVocIndex = 0;
static int gQualityScore = 100;
static uint32_t gLastReadMs = 0;

static void notifyAirQuality() {
  JsonDocument state;
  state["readings"]["quality_score"] = gQualityScore;
  state["readings"]["voc_index"] = gVocIndex;
  state["readings"]["air_quality_label"] = retroSmartAirQualityLabel(gVocIndex);
  state["readings"]["display_present"] = gDisplay.isPresent();
  state["readings"]["display_enabled"] = gDisplay.isEnabled();
  state["status"]["connected"] = gBleModule->isConnected();
  gBleModule->notifyState(state);
}

static void readSensor() {
  if (!gSensorReady) {
    digitalWrite(PIN_STATUS_LED, LOW);
    retroSmartLog("SGP40 not ready for a reading");
    return;
  }

  const int32_t measuredVocIndex = gSgp40.measureVocIndex(
    DEFAULT_TEMPERATURE_C,
    DEFAULT_HUMIDITY_RH
  );

  if (measuredVocIndex < 0) {
    digitalWrite(PIN_STATUS_LED, LOW);
    retroSmartLog("SGP40 VOC index measurement failed");
    return;
  }

  gVocIndex = retroSmartNormalizeAirQualityScore(measuredVocIndex);
  gQualityScore = retroSmartQualityScore100(gVocIndex);
  digitalWrite(PIN_STATUS_LED, HIGH);
  gDisplay.showAirQuality(gQualityScore);
  retroSmartLog(
    "Air quality -> score " + String(gQualityScore) +
    "/100, VOC index " + String(gVocIndex) +
    " (" + String(retroSmartAirQualityLabel(gVocIndex)) + ")"
  );
}

static void handleCommand(const JsonDocument& command) {
  const char* action = command["action"] | "";
  if (strcmp(action, "set_display_enabled") != 0) {
    return;
  }

  const bool requestedEnabled = command["payload"]["value"] | true;
  gDisplay.setEnabled(requestedEnabled);
  if (gDisplay.isEnabled()) {
    gDisplay.showAirQuality(gQualityScore);
  }
  notifyAirQuality();
}

void setup() {
  Serial.begin(115200);
  delay(250);
  retroSmartLog("Starting air quality module setup");
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  gSensorWire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  gDisplay.begin(PIN_DISPLAY_SDA, PIN_DISPLAY_SCL);
  gSensorReady = gSgp40.begin(&gSensorWire);
  retroSmartLog("SGP40 ready -> " + String(gSensorReady ? "true" : "false"));

  RetroSmartIdentity identity = {
    .deviceId = retroSmartDeviceId("RS-AIR"),
    .deviceType = "air_quality_sgp40_v1",
    .model = "Air Quality Module",
    .firmwareVersion = "0.4.0"
  };

  const char* const actions[] = {"set_display_enabled"};
  const char* const readings[] = {
    "quality_score",
    "voc_index",
    "air_quality_label",
    "display_present",
    "display_enabled"
  };

  gBleModule = new RetroSmartBLEModule(
    "RetroSmartAirQuality",
    identity,
    retroSmartCapabilitiesJson(identity.deviceType, actions, 1, readings, 5),
    handleCommand
  );
  gBleModule->begin();
  retroSmartLog("Air quality module setup complete");
}

void loop() {
  if (millis() - gLastReadMs >= READ_INTERVAL_MS) {
    gLastReadMs = millis();
    readSensor();
    notifyAirQuality();
  }
}
