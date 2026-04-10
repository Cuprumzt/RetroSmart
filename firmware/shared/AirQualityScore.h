#pragma once

#include <Arduino.h>

// RetroSmart v1 air quality score bands.
// This stays intentionally simple and is not an official AQI claim.
// Sensor-specific firmware is responsible for producing a normalized 0-500 score.
// The shared helper only clamps the score and maps it to the documented labels:
// 0-50 Excellent
// 51-100 Good
// 101-150 Fair
// 151-200 Moderate
// 201-300 Poor
// 301-500 Very Poor

inline int retroSmartNormalizeAirQualityScore(int32_t score) {
  return constrain(static_cast<int>(score), 0, 500);
}

inline int retroSmartQualityScore100(int normalizedScore) {
  return constrain(100 - ((retroSmartNormalizeAirQualityScore(normalizedScore) + 2) / 5), 0, 100);
}

inline const char* retroSmartAirQualityLabel(int score) {
  if (score <= 50) return "Excellent";
  if (score <= 100) return "Good";
  if (score <= 150) return "Fair";
  if (score <= 200) return "Moderate";
  if (score <= 300) return "Poor";
  return "Very Poor";
}
