#include "../../shared/RetroSmartBLEModule.h"

static constexpr int PIN_MOTOR_PWM = 7;
static constexpr int PIN_MOTOR_IN1 = 8;
static constexpr int PIN_MOTOR_IN2 = 9;
// ESP32-S3 Zero uses GPIO21 for the onboard WS2812, but this project keeps the
// module wiring inside GPIO1-GPIO13. Use GPIO13 for an optional external LED.
static constexpr int PIN_STATUS_LED = 13;

static constexpr uint32_t PWM_FREQUENCY_HZ = 20000;
static constexpr uint8_t PWM_RESOLUTION_BITS = 8;
static constexpr uint8_t PWM_DUTY = 255;
static constexpr uint32_t IDLE_NOTIFY_MS = 1000;
static constexpr uint32_t ACTIVE_NOTIFY_MS = 250;

enum class MotorState {
  stopped,
  forward,
  reverse
};

static RetroSmartBLEModule* gBleModule = nullptr;
static MotorState gMotorState = MotorState::stopped;
static uint32_t gLastStateNotifyMs = 0;

static bool isActiveMotorState(MotorState state) {
  return state == MotorState::forward || state == MotorState::reverse;
}

static const char* motorStateLabel(MotorState state) {
  switch (state) {
    case MotorState::forward:
      return "forward";
    case MotorState::reverse:
      return "reverse";
    case MotorState::stopped:
    default:
      return "stopped";
  }
}

static void writeMotorOutputs(bool in1, bool in2, uint8_t pwmDuty) {
  digitalWrite(PIN_MOTOR_IN1, in1 ? HIGH : LOW);
  digitalWrite(PIN_MOTOR_IN2, in2 ? HIGH : LOW);
  ledcWrite(PIN_MOTOR_PWM, pwmDuty);
}

static void applyMotorState(MotorState state) {
  switch (state) {
    case MotorState::forward:
      writeMotorOutputs(true, false, PWM_DUTY);
      break;
    case MotorState::reverse:
      writeMotorOutputs(false, true, PWM_DUTY);
      break;
    case MotorState::stopped:
    default:
      writeMotorOutputs(false, false, 0);
      break;
  }

  digitalWrite(PIN_STATUS_LED, isActiveMotorState(state) ? HIGH : LOW);
}

static void setMotorState(MotorState state) {
  gMotorState = state;
  applyMotorState(state);
  retroSmartLog("Motor state -> " + String(motorStateLabel(state)));
}

static void notifyMotorState() {
  JsonDocument state;
  state["readings"]["motor_state"] = motorStateLabel(gMotorState);
  state["status"]["connected"] = gBleModule->isConnected();
  gBleModule->notifyState(state);
}

static void handleCommand(const JsonDocument& command) {
  const char* action = command["action"] | "";
  const uint32_t now = millis();

  retroSmartLog("Received action -> " + String(action));

  if (strcmp(action, "motor_run_forward") == 0) {
    setMotorState(MotorState::forward);
  } else if (strcmp(action, "motor_run_reverse") == 0) {
    setMotorState(MotorState::reverse);
  } else if (strcmp(action, "motor_stop") == 0) {
    setMotorState(MotorState::stopped);
  } else {
    retroSmartLog("Unknown motor action ignored");
    return;
  }

  gLastStateNotifyMs = now;
  notifyMotorState();
}

void setup() {
  Serial.begin(115200);
  delay(250);
  retroSmartLog("Starting DC motor module setup");

  pinMode(PIN_MOTOR_IN1, OUTPUT);
  pinMode(PIN_MOTOR_IN2, OUTPUT);
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  ledcAttach(PIN_MOTOR_PWM, PWM_FREQUENCY_HZ, PWM_RESOLUTION_BITS);
  setMotorState(MotorState::stopped);

  RetroSmartIdentity identity = {
    .deviceId = retroSmartDeviceId("RS-DCM"),
    .deviceType = "dc_motor_drv8833_v1",
    .model = "DC Motor Module",
    .firmwareVersion = "0.2.0"
  };

  const char* const actions[] = {
    "motor_run_forward",
    "motor_run_reverse",
    "motor_stop"
  };
  const char* const readings[] = {"motor_state"};

  gBleModule = new RetroSmartBLEModule(
    "RetroSmartDCMotor",
    identity,
    retroSmartCapabilitiesJson(identity.deviceType, actions, 3, readings, 1),
    handleCommand
  );
  gBleModule->begin();
  notifyMotorState();
  retroSmartLog("DC motor module setup complete");
}

void loop() {
  const uint32_t now = millis();

  if (!gBleModule->isConnected() && isActiveMotorState(gMotorState)) {
    setMotorState(MotorState::stopped);
    gLastStateNotifyMs = now;
    notifyMotorState();
    return;
  }

  const uint32_t notifyInterval = isActiveMotorState(gMotorState) ? ACTIVE_NOTIFY_MS : IDLE_NOTIFY_MS;
  if (now - gLastStateNotifyMs >= notifyInterval) {
    gLastStateNotifyMs = now;
    notifyMotorState();
  }
}
