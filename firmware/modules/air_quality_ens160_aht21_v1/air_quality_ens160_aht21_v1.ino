#include <Adafruit_AHTX0.h>
#include <ScioSense_ENS160.h>
#include <Wire.h>

#include "../../shared/AirQualityScore.h"
#include "../../shared/RetroSmartBLEModule.h"

static constexpr int PIN_I2C_SDA = 5;
static constexpr int PIN_I2C_SCL = 6;
// ESP32-S3 Zero uses GPIO21 for the onboard WS2812, but this project keeps the
// module wiring inside GPIO1-GPIO13. Use GPIO13 for an optional external LED.
static constexpr int PIN_STATUS_LED = 13;

static RetroSmartBLEModule* gBleModule = nullptr;
static ScioSense_ENS160 gEns160(ENS160_I2CADDR_1);
static Adafruit_AHTX0 gAht;

static bool gEnsReady = false;
static bool gAhtReady = false;
static uint16_t gEco2Ppm = 400;
static uint16_t gTvocPpb = 0;
static float gTemperatureC = NAN;
static float gHumidityRh = NAN;
static int gAqiScore = 25;
static uint32_t gLastReadMs = 0;

static void notifyAirQuality() {
  JsonDocument state;
  state["readings"]["aqi_score"] = gAqiScore;
  state["readings"]["aqi_label"] = retroSmartAirQualityLabel(gAqiScore);
  state["readings"]["eco2_ppm"] = gEco2Ppm;
  state["readings"]["tvoc_ppb"] = gTvocPpb;
  state["status"]["connected"] = gBleModule->isConnected();
  gBleModule->notifyState(state);
}

static void updateCompensationIfAvailable() {
  if (!gAhtReady || !gEnsReady) {
    return;
  }

  sensors_event_t humidityEvent;
  sensors_event_t temperatureEvent;
  gAht.getEvent(&humidityEvent, &temperatureEvent);
  gTemperatureC = temperatureEvent.temperature;
  gHumidityRh = humidityEvent.relative_humidity;
  gEns160.set_envdata(gTemperatureC, gHumidityRh);
  retroSmartLog(
    "Compensation -> temp " + String(gTemperatureC, 1) +
    " C, humidity " + String(gHumidityRh, 1) + " %"
  );
}

static void readSensors() {
  updateCompensationIfAvailable();

  if (gEnsReady && gEns160.available()) {
    gEns160.measure(true);
    gEns160.measureRaw(true);
    gEco2Ppm = gEns160.geteCO2();
    gTvocPpb = gEns160.getTVOC();
    gAqiScore = retroSmartAirQualityScore(gEco2Ppm, gTvocPpb);
    digitalWrite(PIN_STATUS_LED, HIGH);
    retroSmartLog(
      "Air quality -> eCO2 " + String(gEco2Ppm) +
      " ppm, TVOC " + String(gTvocPpb) +
      " ppb, score " + String(gAqiScore) +
      " (" + String(retroSmartAirQualityLabel(gAqiScore)) + ")"
    );
  } else {
    digitalWrite(PIN_STATUS_LED, LOW);
    retroSmartLog("ENS160 not ready for a reading");
  }
}

static void handleCommand(const JsonDocument& command) {
  // Air quality module is read-only in v1.
}

void setup() {
  Serial.begin(115200);
  delay(250);
  retroSmartLog("Starting air quality module setup");
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  gAhtReady = gAht.begin();
  gEnsReady = gEns160.begin();
  retroSmartLog("AHT21 ready -> " + String(gAhtReady ? "true" : "false"));
  retroSmartLog("ENS160 ready -> " + String(gEnsReady ? "true" : "false"));
  if (gEnsReady) {
    gEns160.setMode(ENS160_OPMODE_STD);
  }

  RetroSmartIdentity identity = {
    .deviceId = retroSmartDeviceId("RS-AIR"),
    .deviceType = "air_quality_ens160_aht21_v1",
    .model = "Air Quality Module",
    .firmwareVersion = "0.1.0"
  };

  const char* const readings[] = {
    "aqi_score",
    "aqi_label",
    "eco2_ppm",
    "tvoc_ppb"
  };

  gBleModule = new RetroSmartBLEModule(
    "RetroSmartAirQuality",
    identity,
    retroSmartCapabilitiesJson(identity.deviceType, nullptr, 0, readings, 4),
    handleCommand
  );
  gBleModule->begin();
  retroSmartLog("Air quality module setup complete");
}

void loop() {
  if (millis() - gLastReadMs >= 1000) {
    gLastReadMs = millis();
    readSensors();
    notifyAirQuality();
  }
}
