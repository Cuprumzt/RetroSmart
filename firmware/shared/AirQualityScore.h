#pragma once

#include <Arduino.h>

// RetroSmart v1 air quality score
// This is intentionally a simple documented prototype score, not an official AQI.
//
// Base score from eCO2:
// 400-600 ppm   -> 25
// 601-800 ppm   -> 75
// 801-1000 ppm  -> 125
// 1001-1500 ppm -> 175
// 1501-2000 ppm -> 250
// >2000 ppm     -> 350
//
// TVOC penalty:
// 0-65 ppb      -> +0
// 66-220 ppb    -> +25
// 221-660 ppb   -> +50
// 661-2200 ppb  -> +100
// >2200 ppb     -> +150
//
// Final score is clamped to 0-500 and mapped to:
// 0-50 Excellent
// 51-100 Good
// 101-150 Fair
// 151-200 Moderate
// 201-300 Poor
// 301-500 Very Poor

inline int retroSmartAirQualityBaseScore(uint16_t eco2Ppm) {
  if (eco2Ppm <= 600) return 25;
  if (eco2Ppm <= 800) return 75;
  if (eco2Ppm <= 1000) return 125;
  if (eco2Ppm <= 1500) return 175;
  if (eco2Ppm <= 2000) return 250;
  return 350;
}

inline int retroSmartVocPenalty(uint16_t tvocPpb) {
  if (tvocPpb <= 65) return 0;
  if (tvocPpb <= 220) return 25;
  if (tvocPpb <= 660) return 50;
  if (tvocPpb <= 2200) return 100;
  return 150;
}

inline int retroSmartAirQualityScore(uint16_t eco2Ppm, uint16_t tvocPpb) {
  int score = retroSmartAirQualityBaseScore(eco2Ppm) + retroSmartVocPenalty(tvocPpb);
  return constrain(score, 0, 500);
}

inline const char* retroSmartAirQualityLabel(int score) {
  if (score <= 50) return "Excellent";
  if (score <= 100) return "Good";
  if (score <= 150) return "Fair";
  if (score <= 200) return "Moderate";
  if (score <= 300) return "Poor";
  return "Very Poor";
}
