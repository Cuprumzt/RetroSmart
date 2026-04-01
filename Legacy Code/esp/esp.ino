#include <Arduino.h>
#include <Wire.h>

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#include <ESP32Servo.h>

#include <OneWire.h>
#include <DallasTemperature.h>

#include <Adafruit_NeoPixel.h>

// ---------------- Pins ----------------
static constexpr int PIN_ID_ADC   = 4;   // GP4 (physical pull-up to 3V3 on your system)
static constexpr int PIN_BUS_SDA  = 5;   // GP5 (I2C SDA OR OneWire DATA)
static constexpr int PIN_BUS_SCL  = 6;   // GP6 (I2C SCL)
static constexpr int PIN_ACT_PWM  = 7;   // GP7
static constexpr int PIN_ACT_DIR  = 8;   // GP8
static constexpr int PIN_ACT_AUX  = 9;   // GP9
static constexpr int PIN_ONBOARD_LED = 21; // WS2812

// ---------------- Profiles ----------------
enum class Profile : uint8_t {
  NONE     = 0,
  ACTUATOR = 1,
  DS18B20  = 2,
  HMC5883L = 3   // NOTE: your module is actually QMC5883L at 0x0D; keep enum name for iOS compatibility
};

static void setProfile(Profile p);

// ---------------- BLE UUIDs ----------------
static BLEUUID kServiceUUID ("12345678-1234-5678-1234-56789ABCDEF0");
static BLEUUID kRawAdcUUID  ("12345678-1234-5678-1234-56789ABCDEF2"); // notify/read uint16 LE
static BLEUUID kCtrlUUID    ("12345678-1234-5678-1234-56789ABCDEF1"); // write
static BLEUUID kTelemUUID   ("12345678-1234-5678-1234-56789ABCDEF3"); // notify (12 bytes)
static BLEUUID kInfoUUID    ("12345678-1234-5678-1234-56789ABCDEF4"); // read

BLECharacteristic* gRawAdcChar = nullptr;
BLECharacteristic* gCtrlChar   = nullptr;
BLECharacteristic* gTelemChar  = nullptr;
BLECharacteristic* gInfoChar   = nullptr;

static constexpr uint32_t kFirmwareVersion = 0x00030004; // v3.0.4

// ---------------- Onboard LED ----------------
static constexpr int LED_COUNT = 1;
Adafruit_NeoPixel led(LED_COUNT, PIN_ONBOARD_LED, NEO_GRB + NEO_KHZ800);

volatile bool gBleConnected = false;
uint32_t gConnectedAtMs = 0;
uint32_t gLastBlinkMs = 0;
bool gBlinkOn = false;

static void setLed(uint8_t r, uint8_t g, uint8_t b, uint8_t brightness = 40) {
  led.setBrightness(brightness);
  led.setPixelColor(0, led.Color(r, g, b));
  led.show();
}

static void updateStatusLed() {
  uint32_t now = millis();
  if (gBleConnected) {
    if (now - gConnectedAtMs <= 3000) setLed(0, 255, 0);
    else                               setLed(0, 0, 0);
  } else {
    if (now - gLastBlinkMs >= 500) {
      gLastBlinkMs = now;
      gBlinkOn = !gBlinkOn;
      if (gBlinkOn) setLed(255, 0, 0);
      else          setLed(0, 0, 0);
    }
  }
}

// ---------------- RAW ID ADC ----------------
static constexpr int kAdcSamples = 32;
static constexpr uint32_t kAdcPollMs = 120;
static constexpr uint16_t kAdcDeltaToNotify = 12;

uint32_t gLastAdcPoll = 0;
uint16_t gLastAdc = 0;

static uint16_t readAdcAveraged() {
  uint32_t sum = 0;
  for (int i = 0; i < kAdcSamples; i++) {
    sum += analogRead(PIN_ID_ADC);
    delayMicroseconds(200);
  }
  return (uint16_t)(sum / kAdcSamples);
}

static void notifyRawAdc(uint16_t adc) {
  if (!gRawAdcChar) return;
  uint8_t payload[2] = { (uint8_t)(adc & 0xFF), (uint8_t)((adc >> 8) & 0xFF) };
  gRawAdcChar->setValue(payload, sizeof(payload));
  gRawAdcChar->notify();
}

// ---------------- Actuation ----------------
Servo gServo;
bool gServoAttached = false;

enum class ActMode : uint8_t { STOP=0, DC=1, SERVO=2, AUX=3 };
ActMode gActMode = ActMode::STOP;

static constexpr uint32_t kPwmFreqHz = 20000;
static constexpr uint8_t  kPwmResBits = 10;
bool gPwmAttached = false;

static void detachServoIfNeeded() {
  if (gServoAttached) {
    gServo.detach();
    gServoAttached = false;
  }
}

static void attachServoIfNeeded() {
  if (!gServoAttached) {
    gServo.setPeriodHertz(50);
    gServo.attach(PIN_ACT_PWM, 500, 2500);
    gServoAttached = true;
  }
}

static void ensureDcPwmReady() {
  if (gPwmAttached) return;
  gPwmAttached = ledcAttach(PIN_ACT_PWM, kPwmFreqHz, kPwmResBits);
}

static void dcWriteDuty(uint16_t duty) {
  ledcWrite(PIN_ACT_PWM, duty);
}

static void stopAllOutputs() {
  detachServoIfNeeded();
  if (gPwmAttached) dcWriteDuty(0);

  pinMode(PIN_ACT_PWM, OUTPUT); digitalWrite(PIN_ACT_PWM, LOW);
  pinMode(PIN_ACT_DIR, OUTPUT); digitalWrite(PIN_ACT_DIR, LOW);
  pinMode(PIN_ACT_AUX, OUTPUT); digitalWrite(PIN_ACT_AUX, LOW);

  gActMode = ActMode::STOP;
}

// ---------------- DS18B20 ----------------
OneWire oneWire(PIN_BUS_SDA);
DallasTemperature ds18b20(&oneWire);

static constexpr uint32_t kTempPollMs = 1000;
uint32_t gLastTempPoll = 0;
float gLastTempC = NAN;

// ---------------- QMC5883L (your module at 0x0D) ----------------
static constexpr uint8_t QMC_ADDR = 0x0D;
static constexpr uint32_t kMagPollMs = 100;
uint32_t gLastMagPoll = 0;
int16_t gMagX = 0, gMagY = 0, gMagZ = 0;
bool gMagOk = false;

static bool qmcWrite(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(QMC_ADDR);
  Wire.write(reg);
  Wire.write(val);
  return Wire.endTransmission() == 0;
}

static bool qmcRead6(int16_t &x, int16_t &y, int16_t &z) {
  Wire.beginTransmission(QMC_ADDR);
  Wire.write(0x00); // data start
  if (Wire.endTransmission(false) != 0) return false;

  if (Wire.requestFrom((int)QMC_ADDR, 6) != 6) return false;

  uint8_t xL = Wire.read(), xH = Wire.read();
  uint8_t yL = Wire.read(), yH = Wire.read();
  uint8_t zL = Wire.read(), zH = Wire.read();

  x = (int16_t)((xH << 8) | xL);
  y = (int16_t)((yH << 8) | yL);
  z = (int16_t)((zH << 8) | zL);
  return true;
}

static bool qmcInit() {
  // Set/Reset period (0x0B), then control (0x09)
  // 0x1D is a common config: OSR 512, RNG 2G, ODR 200Hz, MODE continuous
  bool ok = true;
  ok &= qmcWrite(0x0B, 0x01);
  ok &= qmcWrite(0x09, 0x1D);
  return ok;
}

// ---------------- Telemetry ----------------
static constexpr uint32_t kTelemMs = 200;
uint32_t gLastTelem = 0;

Profile gProfile = Profile::NONE;

// 12 bytes:
// [0] ver=1
// [1] profile
// [2] actMode
// [3] flags: bit0=magOk bit1=tempValid
// [4..5] rawAdc (LE)
// [6..7] tempC_x100 (int16, 0x7FFF invalid)
// [8..9] magX (int16)
// [10..11] magY (int16)
static void notifyTelemetry() {
  if (!gTelemChar) return;

  uint8_t payload[12] = {0};
  payload[0] = 1;
  payload[1] = (uint8_t)gProfile;
  payload[2] = (uint8_t)gActMode;

  uint8_t flags = 0;
  if (gMagOk) flags |= (1 << 0);
  bool tempValid = isfinite(gLastTempC);
  if (tempValid) flags |= (1 << 1);
  payload[3] = flags;

  payload[4] = (uint8_t)(gLastAdc & 0xFF);
  payload[5] = (uint8_t)((gLastAdc >> 8) & 0xFF);

  int16_t t100 = 0x7FFF;
  if (tempValid) {
    float t = gLastTempC;
    if (t > 327.67f) t = 327.67f;
    if (t < -327.68f) t = -327.68f;
    t100 = (int16_t)lroundf(t * 100.0f);
  }
  payload[6] = (uint8_t)(t100 & 0xFF);
  payload[7] = (uint8_t)((t100 >> 8) & 0xFF);

  payload[8]  = (uint8_t)(gMagX & 0xFF);
  payload[9]  = (uint8_t)((gMagX >> 8) & 0xFF);
  payload[10] = (uint8_t)(gMagY & 0xFF);
  payload[11] = (uint8_t)((gMagY >> 8) & 0xFF);

  gTelemChar->setValue(payload, sizeof(payload));
  gTelemChar->notify();
}

// ---------------- Profile switching ----------------
static void stopI2CIfRunning() {
  // If Wire.end() doesn't compile on your core, delete this function body
  // and rely on only calling Wire.begin() in compass profile.
  Wire.end();
}

static void setProfile(Profile p) {
  if (p == gProfile) return;

  // Stop outputs + reset sensor state
  stopAllOutputs();
  gMagOk = false;
  gLastTempC = NAN;

  // Release shared bus pins when leaving compass mode
  if (gProfile == Profile::HMC5883L) {
    stopI2CIfRunning();
  }

  gProfile = p;

  switch (gProfile) {
    case Profile::NONE:
      break;

    case Profile::ACTUATOR:
      break;

    case Profile::DS18B20:
      // Ensure I2C is not holding GP5
      stopI2CIfRunning();
      ds18b20.begin();
      break;

    case Profile::HMC5883L:
      Wire.begin(PIN_BUS_SDA, PIN_BUS_SCL);
      Wire.setClock(100000); // safer for cheap breakouts / long leads
      gMagOk = qmcInit();
      break;
  }
}

// ---------------- Control handling ----------------
static void handleCtrl(const uint8_t* p, size_t n) {
  if (!p || n < 1) return;

  uint8_t cmd = p[0];
  uint8_t a = (n > 1) ? p[1] : 0;
  uint8_t b = (n > 2) ? p[2] : 0;

  switch (cmd) {
    case 0x40: // SET_PROFILE
      setProfile((Profile)a);
      break;

    case 0x00: // STOP_ALL
      setProfile(Profile::NONE);
      stopAllOutputs();
      break;

    case 0x01: { // DC motor (H-bridge)
      if (gProfile != Profile::ACTUATOR) setProfile(Profile::ACTUATOR);

      int8_t speed = (int8_t)a;
      bool auxEnable = (b & (1 << 0)) != 0;
      bool auxBrake  = (b & (1 << 1)) != 0;

      detachServoIfNeeded();
      pinMode(PIN_ACT_DIR, OUTPUT);
      pinMode(PIN_ACT_AUX, OUTPUT);

      bool dir = (speed >= 0);
      uint8_t mag = (uint8_t)min<int>(abs(speed), 100);
      digitalWrite(PIN_ACT_DIR, dir ? HIGH : LOW);

      if (mag == 0) {
        if (gPwmAttached) dcWriteDuty(0);
        digitalWrite(PIN_ACT_AUX, auxBrake ? HIGH : LOW);
      } else {
        ensureDcPwmReady();
        if (gPwmAttached) {
          uint16_t dutyMax = (1u << kPwmResBits) - 1;
          uint16_t duty = (uint32_t)mag * dutyMax / 100u;
          dcWriteDuty(duty);
        }
        digitalWrite(PIN_ACT_AUX, auxEnable ? HIGH : LOW);
      }
      gActMode = ActMode::DC;
    } break;

    case 0x02: { // SERVO
      if (gProfile != Profile::ACTUATOR) setProfile(Profile::ACTUATOR);
      uint8_t angle = min<uint8_t>(a, 180);
      if (gPwmAttached) dcWriteDuty(0);
      attachServoIfNeeded();
      gServo.write(angle);
      gActMode = ActMode::SERVO;
    } break;

    case 0x03: { // AUX
      if (gProfile != Profile::ACTUATOR) setProfile(Profile::ACTUATOR);
      detachServoIfNeeded();
      if (gPwmAttached) dcWriteDuty(0);
      pinMode(PIN_ACT_AUX, OUTPUT);
      digitalWrite(PIN_ACT_AUX, a ? HIGH : LOW);
      gActMode = ActMode::AUX;
    } break;

    default:
      break;
  }
}

// ---------------- BLE callbacks ----------------
class CtrlCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* ch) override {
    const uint8_t* data = (const uint8_t*)ch->getData();
    size_t n = ch->getLength();
    if (data && n > 0) {
      handleCtrl(data, n);
      return;
    }

    String s = ch->getValue();
    if (s.length() <= 0) return;

    static uint8_t buf[32];
    n = (size_t)min((int)s.length(), (int)sizeof(buf));
    for (size_t i = 0; i < n; i++) buf[i] = (uint8_t)s[(int)i];
    handleCtrl(buf, n);
  }
};

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    gBleConnected = true;
    gConnectedAtMs = millis();
  }
  void onDisconnect(BLEServer*) override {
    gBleConnected = false;
    BLEDevice::startAdvertising();
  }
};

// ---------------- Setup / Loop ----------------
void setup() {
  Serial.begin(115200);

  led.begin();
  setLed(255, 0, 0);

  // ID ADC: physical pull-up is present, so don't use internal pull-up
  pinMode(PIN_ID_ADC, INPUT);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  stopAllOutputs();
  setProfile(Profile::NONE);

  BLEDevice::init("RetroSmartController");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(kServiceUUID);

  gRawAdcChar = service->createCharacteristic(
    kRawAdcUUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  gRawAdcChar->addDescriptor(new BLE2902());

  gCtrlChar = service->createCharacteristic(
    kCtrlUUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  gCtrlChar->setCallbacks(new CtrlCallbacks());

  gTelemChar = service->createCharacteristic(
    kTelemUUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  gTelemChar->addDescriptor(new BLE2902());

  gInfoChar = service->createCharacteristic(
    kInfoUUID,
    BLECharacteristic::PROPERTY_READ
  );
  uint8_t info[8] = {0};
  info[0] = 1;
  info[2] = (uint8_t)(kFirmwareVersion & 0xFF);
  info[3] = (uint8_t)((kFirmwareVersion >> 8) & 0xFF);
  info[4] = (uint8_t)((kFirmwareVersion >> 16) & 0xFF);
  info[5] = (uint8_t)((kFirmwareVersion >> 24) & 0xFF);
  gInfoChar->setValue(info, sizeof(info));

  service->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(kServiceUUID);
  adv->setScanResponse(true);
  adv->start();

  gLastAdc = readAdcAveraged();
  notifyRawAdc(gLastAdc);
}

void loop() {
  uint32_t now = millis();

  updateStatusLed();

  // RAW ADC notify
  if (now - gLastAdcPoll >= kAdcPollMs) {
    gLastAdcPoll = now;
    uint16_t adc = readAdcAveraged();
    uint16_t diff = (adc > gLastAdc) ? (adc - gLastAdc) : (gLastAdc - adc);
    if (diff >= kAdcDeltaToNotify) {
      gLastAdc = adc;
      notifyRawAdc(adc);
    }
  }

  // Sensors based on profile
  if (gProfile == Profile::DS18B20) {
    if (now - gLastTempPoll >= kTempPollMs) {
      gLastTempPoll = now;
      ds18b20.requestTemperatures();
      float t = ds18b20.getTempCByIndex(0);
      if (t > -1000.0f && t < 1000.0f) gLastTempC = t;
      else gLastTempC = NAN;
    }
  } else if (gProfile == Profile::HMC5883L) { // QMC5883L handling
    if (now - gLastMagPoll >= kMagPollMs) {
      gLastMagPoll = now;

      if (!gMagOk) {
        Wire.begin(PIN_BUS_SDA, PIN_BUS_SCL);
        Wire.setClock(100000);
        gMagOk = qmcInit();
      }

      if (gMagOk) {
        int16_t x, y, z;
        if (qmcRead6(x, y, z)) {
          gMagX = x; gMagY = y; gMagZ = z;
        } else {
          gMagOk = false;
        }
      }
    }
  }

  // Telemetry notify
  if (now - gLastTelem >= kTelemMs) {
    gLastTelem = now;
    notifyTelemetry();
  }

  delay(5);
}