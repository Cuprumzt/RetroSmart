#include <ESP32Servo.h>

#include "../../shared/RetroSmartBLEModule.h"

static constexpr int PIN_SERVO_SIGNAL = 7;
// ESP32-S3 Zero uses GPIO21 for the onboard WS2812, but this project keeps the
// module wiring inside GPIO1-GPIO13. Use GPIO13 for an optional external LED.
static constexpr int PIN_STATUS_LED = 13;
static constexpr int STARTUP_ANGLE = 5;
static constexpr uint32_t SERVO_STEP_INTERVAL_MS = 12;
static constexpr uint32_t STATE_NOTIFY_INTERVAL_MS = 250;

static RetroSmartBLEModule* gBleModule = nullptr;
static Servo gServo;
static int gCurrentAngle = STARTUP_ANGLE;
static int gTargetAngle = STARTUP_ANGLE;
static uint32_t gLastStateNotifyMs = 0;
static uint32_t gLastServoStepMs = 0;

static int clampedServoAngle(int requestedAngle) {
  return constrain(requestedAngle, 5, 175);
}

static void applyServoAngle(int angle) {
  gCurrentAngle = clampedServoAngle(angle);
  gServo.write(gCurrentAngle);
  retroSmartLog("Servo angle -> " + String(gCurrentAngle));
}

static void updateStatusLED() {
  digitalWrite(PIN_STATUS_LED, gCurrentAngle == gTargetAngle ? LOW : HIGH);
}

static void notifyServoState() {
  JsonDocument state;
  state["readings"]["servo_angle"] = gCurrentAngle;
  state["status"]["connected"] = gBleModule->isConnected();
  gBleModule->notifyState(state);
}

static void handleCommand(const JsonDocument& command) {
  const char* action = command["action"] | "";
  if (strcmp(action, "set_servo_angle") != 0) {
    return;
  }

  int requested = command["payload"]["value"] | STARTUP_ANGLE;
  gTargetAngle = clampedServoAngle(requested);
  updateStatusLED();
  retroSmartLog("Received servo target -> " + String(gTargetAngle));
}

void setup() {
  Serial.begin(115200);
  delay(250);
  retroSmartLog("Starting servo module setup");

  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);
  gServo.setPeriodHertz(50);
  gServo.attach(PIN_SERVO_SIGNAL, 500, 2500);
  applyServoAngle(STARTUP_ANGLE);
  gTargetAngle = gCurrentAngle;
  updateStatusLED();

  RetroSmartIdentity identity = {
    .deviceId = retroSmartDeviceId("RS-SER"),
    .deviceType = "servo_180_v1",
    .model = "Servo Module",
    .firmwareVersion = "0.1.0"
  };

  const char* const actions[] = {"set_servo_angle"};
  const char* const readings[] = {"servo_angle"};

  gBleModule = new RetroSmartBLEModule(
    "RetroSmartServo",
    identity,
    retroSmartCapabilitiesJson(identity.deviceType, actions, 1, readings, 1),
    handleCommand
  );
  gBleModule->begin();
  notifyServoState();
  retroSmartLog("Servo module setup complete");
}

void loop() {
  const uint32_t now = millis();

  if (gCurrentAngle != gTargetAngle && now - gLastServoStepMs >= SERVO_STEP_INTERVAL_MS) {
    gLastServoStepMs = now;
    int nextAngle = gCurrentAngle + (gTargetAngle > gCurrentAngle ? 1 : -1);
    applyServoAngle(nextAngle);
    updateStatusLED();
  }

  if (now - gLastStateNotifyMs >= STATE_NOTIFY_INTERVAL_MS) {
    gLastStateNotifyMs = now;
    notifyServoState();
  }
}
