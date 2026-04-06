#include <Wire.h>
#include "esp_camera.h"

/**
 * DFRobot ESP32-S3 AI Camera v1.1 (DFR1154) - DIAGNOSTIC
 *
 * ARDUINO IDE SETTINGS:
 * - Board: "DFRobot FireBeetle 2 ESP32-S3"
 * - USB CDC On Boot: "Enabled"
 * - Flash Mode: "QIO 80MHz" (CRITICAL)
 * - PSRAM: "OPI PSRAM"
 */

#define SIOD_GPIO_NUM     8
#define SIOC_GPIO_NUM     9
#define XCLK_GPIO_NUM     5

#define Y9_GPIO_NUM       4
#define Y8_GPIO_NUM       6
#define Y7_GPIO_NUM       7
#define Y6_GPIO_NUM      14
#define Y5_GPIO_NUM      17
#define Y4_GPIO_NUM      21
#define Y3_GPIO_NUM      18
#define Y2_GPIO_NUM      16
#define VSYNC_GPIO_NUM    1
#define HREF_GPIO_NUM     2
#define PCLK_GPIO_NUM    15

void scanI2C() {
  Serial.println("\n--- I2C Scan (SDA:8, SCL:9) ---");
  byte error, address;
  int nDevices = 0;
  Wire.begin(SIOD_GPIO_NUM, SIOC_GPIO_NUM);
  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();
    if (error == 0) {
      Serial.printf("I2C rasta 0x%02X", address);
      if (address == 0x3C) Serial.println(" (KAMERA)");
      else if (address == 0x23) Serial.println(" (APŠVIETIMO JUTIKLIS)");
      else Serial.println(" (Nežinoma)");
      nDevices++;
    }
  }
  if (nDevices == 0) Serial.println("Nerasta jokių I2C įrenginių.");
}

void setup() {
  Serial.begin(115200);
  delay(3000);
  Serial.println("\n--- DFRobot ESP32-S3 AI Camera SUPER DIAGNOSTIC ---");

  if (psramFound()) {
    Serial.printf("PSRAM: Rasta! Dydis: %u baitų\n", ESP.getPsramSize());
  } else {
    Serial.println("PSRAM: NERASTA! Kamera neveiks (0x106). Patikrinkite IDE Settings.");
  }

  scanI2C();

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = -1;
  config.pin_reset = -1;
  config.xclk_freq_hz = 20000000;
  config.frame_size = FRAMESIZE_QVGA;
  config.pixel_format = PIXFORMAT_JPEG;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err == ESP_OK) {
    Serial.println("SĖKMĖ! Kamera inicializuota.");
  } else {
    Serial.printf("Klaida (0x%x)\n", err);
  }
}

void loop() {
  delay(1000);
}
