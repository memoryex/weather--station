#include "esp_camera.h"
#include <WiFi.h>

/**
 * DFRobot ESP32-S3 AI Camera v1.1 (DFR1154) - FINAL ROBUST DIAGNOSTIC
 *
 * If you see 'Camera init failed with error 0x106' despite PSRAM being detected,
 * it indicates that the camera library is rejecting the specific combination of
 * pixel format, frame size, or buffer location for your build environment.
 *
 * This sketch attempts multiple initialization modes to identify the cause.
 *
 * ARDUINO IDE SETTINGS:
 * - Board: "DFRobot FireBeetle 2 ESP32-S3"
 * - USB CDC On Boot: "Enabled"
 * - Flash Size: "16MB (128Mb)"
 * - Flash Mode: "QIO 80MHz" (Do NOT use OPI Flash)
 * - Partition Scheme: "16M Flash (3MB APP/9.9MB FATFS)"
 * - PSRAM: "OPI PSRAM"
 * - Flash Frequency: 80MHz
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
const int onboardLED = 3;
const int irLED = 47;

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();
  Serial.println("--- DFRobot ESP32-S3 AI Camera v1.1 Multi-Mode Diagnostic ---");

  // Initialize LEDs
  pinMode(onboardLED, OUTPUT);
  pinMode(irLED, OUTPUT);

  // Power-on delay for stability
  delay(2000);

  // PSRAM Diagnostic
  if (psramFound()) {
    Serial.println("PSRAM detected successfully!");
    Serial.printf("Total PSRAM: %u bytes\n", ESP.getPsramSize());
  } else {
    Serial.println("WARNING: PSRAM NOT DETECTED! Ensure 'OPI PSRAM' is selected.");
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
  config.xclk_freq_hz = 20000000;
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;

  /**
   * ATTEMPT 1: Standard JPEG with PSRAM
   * Most common for camera streaming.
   */
  Serial.println("Initializing: MODE 1 (JPEG + PSRAM)...");
  config.frame_size = FRAMESIZE_QVGA;
  config.pixel_format = PIXFORMAT_JPEG;
  config.fb_location = psramFound() ? CAMERA_FB_IN_PSRAM : CAMERA_FB_IN_DRAM;
  config.fb_count = 2;
  config.jpeg_quality = 12;

  esp_err_t err = esp_camera_init(&config);

  if (err != ESP_OK) {
    Serial.printf("MODE 1 failed (error 0x%x). Retrying with Minimal Mode...\n", err);

    /**
     * ATTEMPT 2: Minimal RGB565 in DRAM
     * Bypasses both PSRAM and the JPEG hardware encoder.
     * Use small frame size (QQVGA) to ensure it fits in internal RAM.
     */
    Serial.println("Initializing: MODE 2 (RGB565 + DRAM)...");
    config.frame_size = FRAMESIZE_QQVGA;
    config.pixel_format = PIXFORMAT_RGB565;
    config.fb_location = CAMERA_FB_IN_DRAM;
    config.fb_count = 1;

    err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("MODE 2 failed (error 0x%x). Initialization halted.\n", err);
        // Error indicator
        while(true) {
          digitalWrite(onboardLED, !digitalRead(onboardLED));
          delay(100);
        }
    } else {
        Serial.println("SUCCESS: Initialized via RGB565 / DRAM fallback.");
    }
  } else {
    Serial.println("SUCCESS: Initialized via Standard JPEG / PSRAM mode.");
  }

  sensor_t *s = esp_camera_sensor_get();
  if (s->id.PID == OV3660_PID) {
    s->set_vflip(s, 1);
    s->set_brightness(s, 1);
    s->set_saturation(s, -2);
    Serial.println("OV3660 Camera detected and adjusted.");
  }

  Serial.println("Camera Ready!");
}

void loop() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Frame capture failed");
  } else {
    Serial.printf("Frame captured: %u bytes (Resolution: %dx%d)\n",
                   (unsigned int)fb->len, fb->width, fb->height);
    esp_camera_fb_return(fb);

    digitalWrite(onboardLED, HIGH);
    delay(50);
    digitalWrite(onboardLED, LOW);
  }

  delay(3000);
}
