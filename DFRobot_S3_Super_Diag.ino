#include <Wire.h>
#include "esp_camera.h"

/**
 * DFRobot ESP32-S3 AI Camera v1.1 - SUPER DIAGNOSTIC
 *
 * If you see '0x23' (Light sensor) but NOT '0x3C' (Camera),
 * the camera sensor is likely loose or faulty.
 *
 * REQUIRED IDE SETTINGS:
 * - Board: "DFRobot FireBeetle 2 ESP32-S3"
 * - USB CDC On Boot: "Enabled"
 * - Flash Mode: "QIO 80MHz" (IMPORTANT: Not OPI)
 * - PSRAM: "OPI PSRAM"
 */

#define SIOD_GPIO_NUM     1
#define SIOC_GPIO_NUM     2
#define XCLK_GPIO_NUM    45

void setup() {
  Serial.begin(115200);
  delay(3000);
  Serial.println("\n\n--- DFRobot ESP32-S3 AI Cam SUPER DIAGNOSTIC ---");

  // 1. Check PSRAM
  if (psramFound()) {
    Serial.printf("PSRAM: FOUND! Size: %u bytes\n", ESP.getPsramSize());
  } else {
    Serial.println("PSRAM: NOT FOUND! Camera will fail (0x106). Check IDE Settings.");
  }

  // 2. Scan I2C Bus (Pins 1 & 2)
  Serial.println("\nScanning I2C Bus (SDA:1, SCL:2)...");
  Wire.begin(SIOD_GPIO_NUM, SIOC_GPIO_NUM);
  byte error, address;
  int nDevices = 0;
  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();
    if (error == 0) {
      Serial.printf("Found device at 0x%02X", address);
      if (address == 0x23) Serial.println(" (LTR-308 Light Sensor - BUS IS ALIVE)");
      else if (address == 0x3C || address == 0x3D) Serial.println(" (CAMERA SENSOR DETECTED!)");
      else Serial.println(" (Unknown)");
      nDevices++;
    }
  }
  if (nDevices == 0) Serial.println("No I2C devices found on pins 1 & 2.");

  // 3. Camera Probe with multiple XCLK speeds
  uint32_t xclk_speeds[] = {20000000, 10000000, 5000000};
  for (int i = 0; i < 3; i++) {
    Serial.printf("\nProbing Camera @ %d MHz...\n", xclk_speeds[i]/1000000);

    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = 39; config.pin_d1 = 40; config.pin_d2 = 41; config.pin_d3 = 4;
    config.pin_d4 = 7;  config.pin_d5 = 8;  config.pin_d6 = 46; config.pin_d7 = 48;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = 5;
    config.pin_vsync = 6;
    config.pin_href = 42;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = -1;
    config.pin_reset = -1;
    config.xclk_freq_hz = xclk_speeds[i];
    config.frame_size = FRAMESIZE_QVGA;
    config.pixel_format = PIXFORMAT_JPEG;
    config.fb_location = CAMERA_FB_IN_PSRAM;
    config.jpeg_quality = 12;
    config.fb_count = 1;
    config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;

    esp_err_t err = esp_camera_init(&config);
    if (err == ESP_OK) {
      Serial.println("SUCCESS! Camera initialized.");
      sensor_t *s = esp_camera_sensor_get();
      Serial.printf("Sensor PID: 0x%04X\n", s->id.PID);
      break;
    } else {
      Serial.printf("Failed (Error 0x%x)\n", err);
      esp_camera_deinit();
      delay(500);
    }
  }

  Serial.println("\nDiagnostic complete. If 0x23 was found but Camera was not, check ribbon cable.");
}

void loop() {
  pinMode(3, OUTPUT);
  digitalWrite(3, !digitalRead(3));
  delay(1000);
}
