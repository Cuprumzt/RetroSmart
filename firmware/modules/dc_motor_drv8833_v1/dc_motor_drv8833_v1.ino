#include "../../shared/RetroSmartBLEModule.h"

static constexpr int PIN_MOTOR_PWM = 7;
static constexpr int PIN_MOTOR_IN1 = 8;
static constexpr int PIN_MOTOR_IN2 = 9;
// ESP32-S3 Zero uses GPIO21 for the onboard WS2812, but this project keeps the
// module wiring inside GPIO1-GPIO13. Use GPIO13 for an optional external LED.
static constexpr int PIN_STATUS_LED = 13;

static constexpr uint32_t PWM_FREQUENCY_HZ = 20000;
static constexpr uint8_t PWM_RESOLUTION_BITS = 8;
static constexpr uint32_t MAX_RUN_MS = 5000;

enum class MotorState {
  stopped,
  forward,
  reverse,
  timedOut
};

static RetroSmartBLEModule* gBleModule = nullptr;
static MotorState gMotorState = MotorState::stopped;
static uint32_t gRunStartedMs = 0;
static uint32_t gLastStateNotifyMs = 0;

static const char* motorStateLabel(MotorState state) {
  switch (state) {
    case MotorState::forward:
      return "forward";
    case MotorState::reverse:
      return "reverse";
    case MotorState::timedOut:
      return "timed_out";
    case MotorState::stopped:
    default:
      return "stopped";
  }
}

static void applyOutputs(MotorState state) {
  switch (state) {
    case MotorState::forward:
      digitalWrite(PIN_MOTOR_IN1, HIGH);
      digitalWrite(PIN_MOTOR_IN2, LOW);
      ledcWrite(PIN_MOTOR_PWM, 255);
      break;
    case MotorState::reverse:
      digitalWrite(PIN_MOTOR_IN1, LOW);
      digitalWrite(PIN_MOTOR_IN2, HIGH);
      ledcWrite(PIN_MOTOR_PWM, 255);
      break;
    case MotorState::timedOut:
    case MotorState::stopped:
    default:
      digitalWrite(PIN_MOTOR_IN1, LOW);
      digitalWrite(PIN_MOTOR_IN2, LOW);
      ledcWrite(PIN_MOTOR_PWM, 0);
      break;
  }

  digitalWrite(PIN_STATUS_LED, state == MotorState::stopped ? LOW : HIGH);
}

static void setMotorState(MotorState state) {
  gMotorState = state;
  gRunStartedMs = (state == MotorState::forward || state == MotorState::reverse) ? millis() : 0;
  applyOutputs(state);
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

  if (strcmp(action, "motor_run_forward") == 0) {
    setMotorState(MotorState::forward);
  } else if (strcmp(action, "motor_run_reverse") == 0) {
    setMotorState(MotorState::reverse);
  } else if (strcmp(action, "motor_stop") == 0) {
    setMotorState(MotorState::stopped);
  } else {
    Serial.print("Unknown motor action: ");
    Serial.println(action);
    return;
  }

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
    .firmwareVersion = "0.1.0"
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

  if ((gMotorState == MotorState::forward || gMotorState == MotorState::reverse) &&
      (now - gRunStartedMs >= MAX_RUN_MS)) {
    setMotorState(MotorState::timedOut);
    notifyMotorState();
  }

  if (now - gLastStateNotifyMs >= 1000) {
    gLastStateNotifyMs = now;
    notifyMotorState();
  }
}
