#include <Wire.h>

/**
 * DFRobot ESP32-S3 AI Camera v1.1 - POWER FIX & SCANNER
 *
 * If your I2C scan was empty, the camera and sensors are powered OFF.
 * This sketch attempts to wake up the power rails using the AXP313A
 * or manual GPIO triggers.
 *
 * IDE SETTINGS:
 * - Board: "DFRobot FireBeetle 2 ESP32-S3"
 * - USB CDC On Boot: "Enabled"
 */

#define SIOD_GPIO_NUM     1
#define SIOC_GPIO_NUM     2
#define ONBOARD_LED       3

void scan() {
  Serial.println("Scanning I2C...");
  byte error, address;
  int nDevices = 0;
  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();
    if (error == 0) {
      Serial.print("Device @ 0x");
      Serial.print(address, HEX);
      if (address == 0x3C) Serial.println(" (CAMERA FOUND!)");
      else if (address == 0x23) Serial.println(" (LIGHT SENSOR FOUND!)");
      else if (address == 0x2C) Serial.println(" (AXP313A POWER CHIP FOUND!)");
      else Serial.println(" (Unknown)");
      nDevices++;
    }
  }
  if (nDevices == 0) Serial.println("No devices found.");
}

void setup() {
  Serial.begin(115200);
  pinMode(ONBOARD_LED, OUTPUT);
  delay(2000);
  Serial.println("\n--- DFRobot ESP32-S3 AI Cam Power Fix Tool ---");

  Wire.begin(SIOD_GPIO_NUM, SIOC_GPIO_NUM);

  // STEP 1: Scan initially
  scan();

  // STEP 2: Try to wake up AXP313A (Power Management IC)
  // Even if not using the library, we can try to send a 'Power ON' command manually
  Serial.println("\nAttempting to wake AXP313A...");
  Wire.beginTransmission(0x2C);
  Wire.write(0x10); // Common register for power control
  Wire.write(0x01); // Try to enable
  Wire.endTransmission();
  delay(500);
  scan();

  // STEP 3: Toggle common Power Enable Pins on DFRobot boards
  int powerPins[] = {38, 42, 48};
  for(int pin : powerPins) {
    Serial.printf("\nToggling GPIO %d HIGH (Possible Power Enable)...\n", pin);
    pinMode(pin, OUTPUT);
    digitalWrite(pin, HIGH);
    delay(500);
    scan();
  }

  Serial.println("\nDiagnostic complete. If sensors appeared, note which step fixed it!");
}

void loop() {
  digitalWrite(ONBOARD_LED, !digitalRead(ONBOARD_LED));
  delay(500);
}
