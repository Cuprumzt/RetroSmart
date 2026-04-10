#pragma once

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>

#include "RetroSmartBLEModule.h"

static constexpr uint8_t RETROSMART_OLED_WIDTH = 96;
static constexpr uint8_t RETROSMART_OLED_HEIGHT = 16;
static constexpr uint8_t RETROSMART_OLED_CANDIDATE_ADDRESSES[] = {0x3C, 0x3D};

static const uint8_t PROGMEM RETROSMART_ICON_THERMOMETER_16[] = {
  0x03, 0xC0, 0x04, 0x20, 0x08, 0x10, 0x08, 0x10,
  0x08, 0x10, 0x08, 0x10, 0x08, 0x10, 0x08, 0x10,
  0x08, 0x10, 0x10, 0x08, 0x10, 0x08, 0x10, 0x08,
  0x10, 0x08, 0x13, 0xC8, 0x0F, 0xF0, 0x03, 0xC0
};

class RetroSmartOLEDStatusDisplay {
 public:
  explicit RetroSmartOLEDStatusDisplay(TwoWire* wire) : wire_(wire), display_(RETROSMART_OLED_WIDTH, RETROSMART_OLED_HEIGHT, wire_, -1) {}

  void begin(int sdaPin, int sclPin) {
    wire_->begin(sdaPin, sclPin);
    present_ = false;
    enabled_ = false;

    for (uint8_t candidate : RETROSMART_OLED_CANDIDATE_ADDRESSES) {
      wire_->beginTransmission(candidate);
      if (wire_->endTransmission() != 0) {
        continue;
      }

      if (!display_.begin(SSD1306_SWITCHCAPVCC, candidate)) {
        continue;
      }

      present_ = true;
      enabled_ = true;
      display_.clearDisplay();
      display_.display();
      retroSmartLog("OLED detected at 0x" + String(candidate, HEX));
      return;
    }

    retroSmartLog("No SSD1306 OLED detected on the display bus");
  }

  bool isPresent() const {
    return present_;
  }

  bool isEnabled() const {
    return present_ && enabled_;
  }

  void setEnabled(bool enabled) {
    enabled_ = present_ && enabled;
    if (!enabled_) {
      clear();
    }
  }

  void clear() {
    if (!present_) {
      return;
    }

    display_.clearDisplay();
    display_.display();
  }

  void showTemperature(float temperatureC) {
    if (!isEnabled()) {
      return;
    }

    const String text = isnan(temperatureC)
      ? "--.-\xF8""C"
      : String(temperatureC, 1) + "\xF8""C";
    drawSingleLine(RETROSMART_ICON_THERMOMETER_16, text);
  }

  void showAirQuality(int qualityScore) {
    if (!isEnabled()) {
      return;
    }

    const int limitedScore = constrain(qualityScore, 0, 99);
    const String label = limitedScore >= 60 ? "Good" : "Poor";
    drawAirQualityLine(label + String(limitedScore));
  }

 private:
  void drawSingleLine(const uint8_t* icon, const String& text) {
    display_.clearDisplay();
    display_.drawBitmap(0, 0, icon, 16, 16, SSD1306_WHITE);
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

  TwoWire* wire_;
  Adafruit_SSD1306 display_;
  bool present_ = false;
  bool enabled_ = false;
};
