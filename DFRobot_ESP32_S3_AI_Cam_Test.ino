#include "esp_camera.h"
#include <WiFi.h>

/**
 * DFRobot ESP32-S3 AI Camera v1.1 (DFR1154) Diagnostic Test Code
 *
 * ERROR 0x106 (ESP_ERR_NOT_SUPPORTED) Troubleshooting:
 * 1. Ensure PSRAM is enabled in Arduino IDE: Tools -> PSRAM -> "OPI PSRAM".
 * 2. This code includes a diagnostic check for PSRAM.
 *
 * Arduino IDE Settings:
 * - Board: "DFRobot FireBeetle 2 ESP32-S3"
 * - USB CDC On Boot: "Enabled"
 * - Flash Size: "16MB"
 * - Partition Scheme: "16M Flash (3MB APP/9.9MB FATFS)"
 * - PSRAM: "OPI PSRAM" (VERY IMPORTANT)
 */

// Camera Pin Definitions (DFRobot FireBeetle 2 ESP32-S3)
#define PWDN_GPIO_NUM    -1
#define RESET_GPIO_NUM   -1
#define XCLK_GPIO_NUM    45
#define SIOD_GPIO_NUM     1
#define SIOC_GPIO_NUM     2

#define Y9_GPIO_NUM      48
#define Y8_GPIO_NUM      46
#define Y7_GPIO_NUM       8
#define Y6_GPIO_NUM       7
#define Y5_GPIO_NUM       4
#define Y4_GPIO_NUM      41
#define Y3_GPIO_NUM      40
#define Y2_GPIO_NUM      39
#define VSYNC_GPIO_NUM    6
#define HREF_GPIO_NUM    42
#define PCLK_GPIO_NUM     5

// LED Indicators
const int onboardLED = 3;  // Onboard LED GPIO
const int irLED = 47;      // Infrared illumination LED GPIO

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();
  Serial.println("--- DFRobot ESP32-S3 AI Camera v1.1 Diagnostic ---");

  // Initialize LEDs
  pinMode(onboardLED, OUTPUT);
  pinMode(irLED, OUTPUT);

  // Flash LEDs to indicate start
  digitalWrite(onboardLED, HIGH);
  digitalWrite(irLED, HIGH);
  delay(500);
  digitalWrite(onboardLED, LOW);
  digitalWrite(irLED, LOW);

  // PSRAM Diagnostic
  if (psramFound()) {
    Serial.println("PSRAM detected successfully!");
    Serial.printf("Total PSRAM: %u bytes\n", ESP.getPsramSize());
    Serial.printf("Free PSRAM: %u bytes\n", ESP.getFreePsram());
  } else {
    Serial.println("WARNING: PSRAM NOT DETECTED!");
    Serial.println("Check IDE Settings: Tools -> PSRAM -> 'OPI PSRAM'");
  }

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
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  // Use lower frequency for stability during testing
  config.xclk_freq_hz = 10000000;

  // Check PSRAM for format selection
  if (psramFound()) {
    config.frame_size = FRAMESIZE_QVGA;
    config.pixel_format = PIXFORMAT_JPEG;
    config.fb_location = CAMERA_FB_IN_PSRAM;
    config.jpeg_quality = 12;
    config.fb_count = 2;
  } else {
    // Fallback if PSRAM is missing - uses Internal RAM
    Serial.println("Falling back to Internal RAM mode (No JPEG support)...");
    config.frame_size = FRAMESIZE_QQVGA;
    config.pixel_format = PIXFORMAT_RGB565; // RGB565 instead of JPEG
    config.fb_location = CAMERA_FB_IN_DRAM;
    config.fb_count = 1;
  }

  // Camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x\n", err);
    if (err == 0x106) {
        Serial.println("Hint: Error 0x106 is usually due to missing PSRAM.");
    }
    // Blink onboard LED fast on error
    while(true) {
      digitalWrite(onboardLED, !digitalRead(onboardLED));
      delay(100);
    }
  }

  sensor_t *s = esp_camera_sensor_get();
  if (s->id.PID == OV3660_PID) {
    s->set_vflip(s, 1);        // Flip vertically
    s->set_brightness(s, 1);   // Increase brightness
    s->set_saturation(s, -2);  // Lower saturation
    Serial.println("OV3660 Camera detected and initialized.");
  }

  Serial.println("Camera Ready!");
}

void loop() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
  } else {
    Serial.printf("Frame captured: %u bytes\n", (unsigned int)fb->len);
    esp_camera_fb_return(fb);

    // Blink LEDs on successful capture
    digitalWrite(onboardLED, HIGH);
    digitalWrite(irLED, HIGH);
    delay(50);
    digitalWrite(onboardLED, LOW);
    digitalWrite(irLED, LOW);
  }

  delay(3000);
}
