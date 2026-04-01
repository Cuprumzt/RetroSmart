#pragma once

#include <Arduino.h>
#include <ArduinoJson.h>

#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

static constexpr const char* RETROSMART_SERVICE_UUID = "D973F2E0-71A7-4E26-A72A-4A130B83A001";
static constexpr const char* RETROSMART_IDENTITY_UUID = "D973F2E0-71A7-4E26-A72A-4A130B83A002";
static constexpr const char* RETROSMART_CAPABILITIES_UUID = "D973F2E0-71A7-4E26-A72A-4A130B83A003";
static constexpr const char* RETROSMART_STATE_UUID = "D973F2E0-71A7-4E26-A72A-4A130B83A004";
static constexpr const char* RETROSMART_COMMAND_UUID = "D973F2E0-71A7-4E26-A72A-4A130B83A005";

struct RetroSmartIdentity {
  String deviceId;
  String deviceType;
  String model;
  String firmwareVersion;
};

inline void retroSmartLog(const String& message) {
  Serial.print("[RetroSmart] ");
  Serial.println(message);
}

inline void retroSmartLogJson(const char* label, const String& json) {
  Serial.print("[RetroSmart] ");
  Serial.print(label);
  Serial.print(": ");
  Serial.println(json);
}

inline String retroSmartIdentityJson(const RetroSmartIdentity& identity) {
  JsonDocument doc;
  doc["device_id"] = identity.deviceId;
  doc["device_type"] = identity.deviceType;
  doc["model"] = identity.model;
  doc["fw_version"] = identity.firmwareVersion;

  String output;
  serializeJson(doc, output);
  return output;
}

inline String retroSmartCapabilitiesJson(
  const String& deviceType,
  const char* const* actions,
  size_t actionCount,
  const char* const* readings,
  size_t readingCount
) {
  JsonDocument doc;
  doc["device_type"] = deviceType;

  JsonArray actionsArray = doc["actions"].to<JsonArray>();
  for (size_t index = 0; index < actionCount; index++) {
    actionsArray.add(actions[index]);
  }

  JsonArray readingsArray = doc["readings"].to<JsonArray>();
  for (size_t index = 0; index < readingCount; index++) {
    readingsArray.add(readings[index]);
  }

  String output;
  serializeJson(doc, output);
  return output;
}

inline String retroSmartDeviceId(const char* prefix) {
  uint64_t chipId = ESP.getEfuseMac();
  char suffix[7];
  snprintf(suffix, sizeof(suffix), "%06llX", chipId & 0xFFFFFFULL);
  return String(prefix) + "-" + suffix;
}

typedef void (*RetroSmartCommandHandler)(const JsonDocument&);

class RetroSmartBLEModule;

class RetroSmartServerCallbacks : public BLEServerCallbacks {
 public:
  explicit RetroSmartServerCallbacks(RetroSmartBLEModule* owner) : owner_(owner) {}

  void onConnect(BLEServer* server) override;
  void onDisconnect(BLEServer* server) override;

 private:
  RetroSmartBLEModule* owner_;
};

class RetroSmartCommandCallbacks : public BLECharacteristicCallbacks {
 public:
  explicit RetroSmartCommandCallbacks(RetroSmartBLEModule* owner) : owner_(owner) {}

  void onWrite(BLECharacteristic* characteristic) override;

 private:
  RetroSmartBLEModule* owner_;
};

class RetroSmartBLEModule {
 public:
  RetroSmartBLEModule(
    const String& bleName,
    const RetroSmartIdentity& identity,
    const String& capabilitiesJson,
    RetroSmartCommandHandler commandHandler
  ) :
    bleName_(bleName),
    identity_(identity),
    capabilitiesJson_(capabilitiesJson),
    commandHandler_(commandHandler),
    serverCallbacks_(this),
    commandCallbacks_(this) {}

  void begin() {
    retroSmartLog("Booting BLE module");
    BLEDevice::init(bleName_.c_str());
    BLEServer* server = BLEDevice::createServer();
    server->setCallbacks(&serverCallbacks_);

    const String identityJson = retroSmartIdentityJson(identity_);
    retroSmartLog("BLE name: " + bleName_);
    retroSmartLog("Device ID: " + identity_.deviceId);
    retroSmartLog("Device type: " + identity_.deviceType);
    retroSmartLog("Firmware version: " + identity_.firmwareVersion);
    retroSmartLog("Service UUID: " + String(RETROSMART_SERVICE_UUID));
    retroSmartLogJson("Identity JSON", identityJson);
    retroSmartLogJson("Capabilities JSON", capabilitiesJson_);

    BLEService* service = server->createService(RETROSMART_SERVICE_UUID);

    identityCharacteristic_ = service->createCharacteristic(
      RETROSMART_IDENTITY_UUID,
      BLECharacteristic::PROPERTY_READ
    );
    identityCharacteristic_->setValue(identityJson.c_str());

    capabilitiesCharacteristic_ = service->createCharacteristic(
      RETROSMART_CAPABILITIES_UUID,
      BLECharacteristic::PROPERTY_READ
    );
    capabilitiesCharacteristic_->setValue(capabilitiesJson_.c_str());

    stateCharacteristic_ = service->createCharacteristic(
      RETROSMART_STATE_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    stateCharacteristic_->addDescriptor(new BLE2902());

    commandCharacteristic_ = service->createCharacteristic(
      RETROSMART_COMMAND_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    commandCharacteristic_->setCallbacks(&commandCallbacks_);

    service->start();

    BLEAdvertising* advertising = BLEDevice::getAdvertising();
    advertising->addServiceUUID(RETROSMART_SERVICE_UUID);
    advertising->setScanResponse(true);
    advertising->setMinPreferred(0x06);
    advertising->setMinPreferred(0x12);
    advertising->start();
    retroSmartLog("Advertising started and ready for iPhone scans");
  }

  void notifyState(JsonDocument& stateDocument) {
    if (!stateCharacteristic_) {
      return;
    }

    stateDocument["device_id"] = identity_.deviceId;
    String output;
    serializeJson(stateDocument, output);
    stateCharacteristic_->setValue(output.c_str());
    stateCharacteristic_->notify();
    retroSmartLogJson("State notify", output);
  }

  bool isConnected() const {
    return connected_;
  }

  void handleCommandPayload(const String& payload) {
    retroSmartLogJson("Command write", payload);

    if (!commandHandler_) {
      return;
    }

    JsonDocument document;
    DeserializationError error = deserializeJson(document, payload);
    if (error) {
      Serial.print("RetroSmart command JSON error: ");
      Serial.println(error.c_str());
      return;
    }

    commandHandler_(document);
  }

  void setConnected(bool connected) {
    connected_ = connected;
  }

 private:
  String bleName_;
  RetroSmartIdentity identity_;
  String capabilitiesJson_;
  RetroSmartCommandHandler commandHandler_;
  bool connected_ = false;

  BLECharacteristic* identityCharacteristic_ = nullptr;
  BLECharacteristic* capabilitiesCharacteristic_ = nullptr;
  BLECharacteristic* stateCharacteristic_ = nullptr;
  BLECharacteristic* commandCharacteristic_ = nullptr;

  RetroSmartServerCallbacks serverCallbacks_;
  RetroSmartCommandCallbacks commandCallbacks_;
};

inline void RetroSmartServerCallbacks::onConnect(BLEServer* server) {
  owner_->setConnected(true);
  retroSmartLog("Central connected");
}

inline void RetroSmartServerCallbacks::onDisconnect(BLEServer* server) {
  owner_->setConnected(false);
  retroSmartLog("Central disconnected, restarting advertising");
  BLEDevice::startAdvertising();
}

inline void RetroSmartCommandCallbacks::onWrite(BLECharacteristic* characteristic) {
  String payload = characteristic->getValue();
  owner_->handleCommandPayload(payload);
}
