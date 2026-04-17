#pragma once

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>

#include "RetroSmartBLEModule.h"

static constexpr uint8_t RETROSMART_OLED_WIDTH = 96;
static constexpr uint8_t RETROSMART_OLED_HEIGHT = 16;
static constexpr uint8_t RETROSMART_OLED_CANDIDATE_ADDRESSES[] = {0x3C, 0x3D};
static constexpr uint32_t RETROSMART_OLED_REPROBE_PRESENT_INTERVAL_MS = 1000;
static constexpr uint32_t RETROSMART_OLED_REPROBE_ABSENT_INTERVAL_MS = 5000;

class RetroSmartOLEDStatusDisplay {
 public:
  explicit RetroSmartOLEDStatusDisplay(TwoWire* wire) : wire_(wire), display_(RETROSMART_OLED_WIDTH, RETROSMART_OLED_HEIGHT, wire_, -1) {}

  void begin(int sdaPin, int sclPin) {
    wire_->begin(sdaPin, sclPin);
    refresh(true);
  }

  bool isPresent() const {
    return present_;
  }

  bool isEnabled() const {
    return present_ && userEnabled_;
  }

  void setEnabled(bool enabled) {
    userEnabled_ = enabled;
    if (!isEnabled()) {
      clear();
    }
  }

  bool refresh(bool force = false) {
    const uint32_t now = millis();
    const uint32_t reprobeInterval = present_
      ? RETROSMART_OLED_REPROBE_PRESENT_INTERVAL_MS
      : RETROSMART_OLED_REPROBE_ABSENT_INTERVAL_MS;
    if (!force && (now - lastProbeMs_) < reprobeInterval) {
      return present_;
    }

    lastProbeMs_ = now;
    const uint8_t detectedAddress = detectAddress();
    if (detectedAddress == 0) {
      if (present_) {
        retroSmartLog("OLED disconnected from the display bus");
      } else if (force) {
        retroSmartLog("No SSD1306 OLED detected on the display bus");
      }

      present_ = false;
      detectedAddress_ = 0;
      renderDirty_ = true;
      return false;
    }

    if (!present_ || detectedAddress_ != detectedAddress) {
      if (!display_.begin(SSD1306_SWITCHCAPVCC, detectedAddress)) {
        present_ = false;
        detectedAddress_ = 0;
        retroSmartLog("SSD1306 init failed at 0x" + String(detectedAddress, HEX));
        return false;
      }

      display_.clearDisplay();
      display_.display();
      detectedAddress_ = detectedAddress;
      renderDirty_ = true;
      retroSmartLog("OLED detected at 0x" + String(detectedAddress, HEX));
    }

    present_ = true;
    return true;
  }

  void clear() {
    if (!present_) {
      renderDirty_ = true;
      return;
    }

    display_.clearDisplay();
    display_.display();
    renderDirty_ = true;
  }

  void showTemperature(float temperatureC) {
    refresh();
    if (!isEnabled()) {
      return;
    }

    if (!renderDirty_ && lastRenderMode_ == RenderMode::temperature && sameTemperature(temperatureC, lastRenderedTemperatureC_)) {
      return;
    }

    const String text = isnan(temperatureC)
      ? "--.-\xF8""C"
      : String(temperatureC, 1) + "\xF8""C";
    drawTemperatureLine(temperatureC, text);
    lastRenderMode_ = RenderMode::temperature;
    lastRenderedTemperatureC_ = temperatureC;
    renderDirty_ = false;
  }

  void showAirQuality(int qualityScore) {
    refresh();
    if (!isEnabled()) {
      return;
    }

    const int limitedScore = constrain(qualityScore, 0, 99);
    if (!renderDirty_ && lastRenderMode_ == RenderMode::airQuality && lastRenderedAirQualityScore_ == limitedScore) {
      return;
    }

    const String label = limitedScore >= 60 ? "Good" : "Poor";
    drawAirQualityLine(label + String(limitedScore));
    lastRenderMode_ = RenderMode::airQuality;
    lastRenderedAirQualityScore_ = limitedScore;
    renderDirty_ = false;
  }

 private:
  enum class RenderMode {
    none,
    temperature,
    airQuality
  };

  uint8_t detectAddress() {
    for (uint8_t candidate : RETROSMART_OLED_CANDIDATE_ADDRESSES) {
      wire_->beginTransmission(candidate);
      if (wire_->endTransmission() == 0) {
        return candidate;
      }
    }

    return 0;
  }

  bool sameTemperature(float lhs, float rhs) const {
    if (isnan(lhs) && isnan(rhs)) {
      return true;
    }

    if (isnan(lhs) || isnan(rhs)) {
      return false;
    }

    return fabsf(lhs - rhs) < 0.05f;
  }

  void drawTemperatureLine(float temperatureC, const String& text) {
    display_.clearDisplay();
    drawTemperatureIcon(temperatureC);
    display_.setTextColor(SSD1306_WHITE);
    display_.cp437(true);
    display_.setTextSize(2);
    display_.setCursor(20, 0);
    display_.print(text);
    display_.display();
  }

  void drawAirQualityLine(const String& text) {
    display_.clearDisplay();
    drawWindIcon();
    display_.setTextColor(SSD1306_WHITE);
    display_.cp437(true);
    display_.setTextSize(2);
    display_.setCursor(20, 0);
    display_.print(text);
    display_.display();
  }

  void drawWindIcon() {
    display_.drawLine(1, 4, 7, 4, SSD1306_WHITE);
    display_.drawCircleHelper(9, 4, 2, 1, SSD1306_WHITE);

    display_.drawLine(1, 8, 12, 8, SSD1306_WHITE);
    display_.drawCircleHelper(12, 8, 3, 2, SSD1306_WHITE);

    display_.drawLine(1, 12, 9, 12, SSD1306_WHITE);
    display_.drawCircleHelper(9, 12, 2, 2, SSD1306_WHITE);
  }

  void drawTemperatureIcon(float temperatureC) {
    constexpr int bulbCenterX = 6;
    constexpr int bulbCenterY = 12;
    constexpr int bulbRadius = 3;
    constexpr int stemOuterX = 5;
    constexpr int stemOuterY = 2;
    constexpr int stemOuterWidth = 3;
    constexpr int stemOuterHeight = 8;
    constexpr int stemInnerX = 6;
    constexpr int stemInnerY = 3;
    constexpr int stemInnerWidth = 1;
    constexpr int stemInnerHeight = 6;

    display_.drawRoundRect(stemOuterX, stemOuterY, stemOuterWidth, stemOuterHeight, 1, SSD1306_WHITE);
    display_.drawCircle(bulbCenterX, bulbCenterY, bulbRadius, SSD1306_WHITE);

    if (isnan(temperatureC)) {
      return;
    }

    const float normalizedFill = constrain((temperatureC - 20.0f) / 10.0f, 0.0f, 1.0f);
    const int filledStemPixels = static_cast<int>(normalizedFill * stemInnerHeight + 0.5f);
    const int stemFillHeight = constrain(filledStemPixels, 0, stemInnerHeight);

    if (normalizedFill > 0.0f) {
      display_.fillCircle(bulbCenterX, bulbCenterY, bulbRadius - 1, SSD1306_WHITE);
    }

    if (stemFillHeight > 0) {
      const int fillTopY = stemInnerY + stemInnerHeight - stemFillHeight;
      display_.fillRect(stemInnerX, fillTopY, stemInnerWidth, stemFillHeight, SSD1306_WHITE);
    }
  }

  TwoWire* wire_;
  Adafruit_SSD1306 display_;
  uint32_t lastProbeMs_ = 0;
  uint8_t detectedAddress_ = 0;
  bool present_ = false;
  bool userEnabled_ = true;
  bool renderDirty_ = true;
  RenderMode lastRenderMode_ = RenderMode::none;
  float lastRenderedTemperatureC_ = NAN;
  int lastRenderedAirQualityScore_ = -1;
};
