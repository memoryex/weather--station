#include "esp_camera.h"
#include <WiFi.h>

/**
 * DFRobot ESP32-S3 AI Camera v1.1 (DFR1154) - CAMERA WEB SERVER
 *
 * This is a robust, self-contained version of the CameraWebServer example
 * specifically for the DFRobot FireBeetle 2 ESP32-S3 AI Cam (v1.1).
 *
 * ARDUINO IDE SETTINGS (CRITICAL):
 * - Board: "DFRobot FireBeetle 2 ESP32-S3"
 * - USB CDC On Boot: "Enabled"
 * - Flash Mode: "QIO 80MHz" (DO NOT USE OPI FLASH)
 * - PSRAM: "OPI PSRAM"
 */

// --- DFRobot FireBeetle 2 ESP32-S3 Pin Mappings ---
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
#define LED_GPIO_NUM      3
#define IR_LED_GPIO_NUM  47

// --- WiFi Credentials ---
const char *ssid = "Bijunu_g";
const char *password = "memoryexx";

void startCameraServer();

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();
  Serial.println("--- DFRobot ESP32-S3 AI Cam WebServer ---");

  // PSRAM Diagnostic (Crucial for high resolutions)
  if (!psramFound()) {
    Serial.println("CRITICAL ERROR: PSRAM not found! Ensure 'OPI PSRAM' is selected in IDE.");
  } else {
    Serial.printf("PSRAM initialized. Total size: %u bytes\n", ESP.getPsramSize());
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
  config.frame_size = FRAMESIZE_UXGA;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode = CAMERA_GRAB_LATEST;
  config.fb_location = psramFound() ? CAMERA_FB_IN_PSRAM : CAMERA_FB_IN_DRAM;
  config.jpeg_quality = 12;
  config.fb_count = 2;

  // Initializing camera
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x\n", err);
    Serial.println("If error is 0x106, check PSRAM settings and Board selection.");
    return;
  }

  // Safety check for sensor pointer to avoid 'LoadProhibited' panic
  sensor_t *s = esp_camera_sensor_get();
  if (s != NULL) {
    if (s->id.PID == OV3660_PID) {
      s->set_vflip(s, 1);
      s->set_brightness(s, 1);
      s->set_saturation(s, -2);
      Serial.println("OV3660 detected and adjusted.");
    }
    s->set_framesize(s, FRAMESIZE_QVGA);
  } else {
    Serial.println("WARNING: Could not obtain sensor pointer!");
  }

  // Connect to WiFi
  WiFi.begin(ssid, password);
  WiFi.setSleep(false);

  Serial.print("WiFi connecting");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");

  // Start web server (This function must be defined in another tab or omitted if not needed)
  // For a standalone test, you can use the official 'CameraWebServer' project's app_httpd.cpp
  Serial.print("Camera Ready! Use 'http://");
  Serial.print(WiFi.localIP());
  Serial.println("' to connect");

  /**
   * IMPORTANT: To use the full Web Server, you must add the 'app_httpd.cpp' file
   * from the official ESP32 CameraWebServer example to this project.
   *
   * For now, we only print the IP address to verify connectivity.
   */
  Serial.println("Note: Web Server function (startCameraServer) is commented out.");
  // startCameraServer();
}

void loop() {
  delay(10000);
}
