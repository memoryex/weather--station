/**
 * PSRAM Verification Sketch for ESP32-S3-WROOM-1-N16R8
 * Use this to verify if your Arduino IDE settings have successfully enabled PSRAM.
 * The Camera WILL NOT WORK (Error 0x106) if PSRAM is not correctly enabled.
 *
 * REQUIRED SETTINGS:
 * - PSRAM: "OPI PSRAM"
 * - Flash Mode: "QIO 80MHz"
 */

void setup() {
  Serial.begin(115200);
  delay(3000);
  Serial.println("\n--- ESP32-S3 PSRAM Verification ---");

  if (psramFound()) {
    Serial.println("SUCCESS: PSRAM was found and is enabled!");
    Serial.printf("Total PSRAM size: %d bytes\n", ESP.getPsramSize());
    Serial.printf("Free PSRAM: %d bytes\n", ESP.getFreePsram());

    // Attempt a test allocation in PSRAM
    uint8_t* psram_buffer = (uint8_t*)ps_malloc(1024 * 1024); // Allocate 1MB
    if (psram_buffer != NULL) {
      Serial.println("TEST: Successfully allocated 1MB in PSRAM.");
      free(psram_buffer);
    } else {
      Serial.println("TEST FAILURE: Could not allocate memory in PSRAM despite it being 'found'.");
    }
  } else {
    Serial.println("CRITICAL FAILURE: PSRAM NOT FOUND!");
    Serial.println("Check your IDE Settings: Change 'PSRAM' to 'OPI PSRAM'.");
    Serial.println("If using 'ESP32S3 Dev Module', ensure Flash Mode is 'QIO'.");
  }
}

void loop() {
  // Blink onboard LED if it works
  pinMode(3, OUTPUT);
  digitalWrite(3, HIGH);
  delay(500);
  digitalWrite(3, LOW);
  delay(500);
}
