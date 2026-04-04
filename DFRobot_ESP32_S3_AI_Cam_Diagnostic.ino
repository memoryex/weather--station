#include <Wire.h>
#include "esp_camera.h"

/**
 * DFRobot ESP32-S3 AI Camera v1.1 (DFR1154) - FULL HARDWARE DIAGNOSTIC
 *
 * This sketch scans the I2C bus and verifies sensor communication
 * to troubleshoot the "Detected camera not supported" (0x106) error.
 *
 * FINAL IDE SETTINGS (For N16R8 module):
 * - Board: "DFRobot FireBeetle 2 ESP32-S3"
 * - USB CDC On Boot: "Enabled"
 * - Flash Mode: "QIO 80MHz"
 * - PSRAM: "OPI PSRAM"
 * - Flash Frequency: 80MHz
 */

#define SIOD_GPIO_NUM     1
#define SIOC_GPIO_NUM     2
#define XCLK_GPIO_NUM    45
#define PWDN_GPIO_NUM    -1
#define RESET_GPIO_NUM   -1

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

const int onboardLED = 3;

void scanI2C() {
  Serial.println("\n--- I2C Bus Scan (SDA:1, SCL:2) ---");
  byte error, address;
  int nDevices = 0;

  Wire.begin(SIOD_GPIO_NUM, SIOC_GPIO_NUM);

  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();

    if (error == 0) {
      Serial.print("I2C device found at address 0x");
      if (address < 16) Serial.print("0");
      Serial.print(address, HEX);

      if (address == 0x3C) Serial.println(" (Possibly Camera Sensor)");
      else if (address == 0x3D) Serial.println(" (Possibly Camera Sensor Alternate)");
      else if (address == 0x23) Serial.println(" (LTR-308 Ambient Light Sensor)");
      else Serial.println(" (Unknown Device)");

      nDevices++;
    } else if (error == 4) {
      Serial.print("Unknown error at address 0x");
      if (address < 16) Serial.print("0");
      Serial.println(address, HEX);
    }
  }

  if (nDevices == 0) Serial.println("No I2C devices found. Check sensor connection!");
  else Serial.println("I2C Scan Complete.");
}

void checkCameraInit() {
  Serial.println("\n--- Camera Initialization Test (Minimal Mode) ---");

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

  // Use ultra-low XCLK for maximal compatibility during probe
  config.xclk_freq_hz = 5000000;
  config.frame_size = FRAMESIZE_QQVGA;
  config.pixel_format = PIXFORMAT_RGB565;
  config.fb_location = CAMERA_FB_IN_DRAM;
  config.fb_count = 1;
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x\n", err);
    if (err == 0x106) {
      Serial.println("Hint: 0x106 (NOT_SUPPORTED) means the driver didn't find the sensor.");
      Serial.println("Action: Update ESP32 Board Manager to latest version (e.g., 2.0.14 or 3.0.x).");
    }
  } else {
    Serial.println("Camera successfully initialized in Minimal Mode!");
    sensor_t *s = esp_camera_sensor_get();
    Serial.printf("Sensor PID: 0x%x\n", s->id.PID);
  }
}

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n--- DFRobot ESP32-S3 AI Camera Hardware Diagnostic ---");

  pinMode(onboardLED, OUTPUT);
  digitalWrite(onboardLED, HIGH);

  // 1. Scan I2C Bus
  scanI2C();

  // 2. Try Camera Init
  checkCameraInit();

  Serial.println("\nDiagnostic finished. Please provide the output above.");
}

void loop() {
  digitalWrite(onboardLED, !digitalRead(onboardLED));
  delay(1000);
}
