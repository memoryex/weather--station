#include <HardwareSerial.h>
#include <Adafruit_NeoPixel.h>

// Pin configuration for ESP32-C3 and DX-LR22 868MHz LoRa module
#define RGB_PIN 8
#define NUMPIXELS 1

#define LORA_RX 6
#define LORA_TX 7
#define LORA_BAUD 9600

HardwareSerial LoRa(1);
Adafruit_NeoPixel pixel(NUMPIXELS, RGB_PIN, NEO_GRB + NEO_KHZ800);

unsigned long lastTemp = 0;
const unsigned long TEMP_INTERVAL = 5000; // Send CPU temperature every 5 seconds

String inputBuffer = "";

void setColor(int r, int g, int b) {
  pixel.setPixelColor(0, pixel.Color(r, g, b));
  pixel.show();
}

void processCommand(String msg) {
  msg.trim();
  if (msg.length() == 0) return;

  Serial.print("Received command: ");
  Serial.println(msg);

  if (msg.startsWith("RGB:")) {
    int r = 0, g = 0, b = 0;
    if (sscanf(msg.c_str(), "RGB:%d,%d,%d", &r, &g, &b) == 3) {
      r = constrain(r, 0, 255);
      g = constrain(g, 0, 255);
      b = constrain(b, 0, 255);

      setColor(r, g, b);
      LoRa.printf("RGB_OK:%d,%d,%d\n", r, g, b);
      Serial.printf("RGB updated to (%d, %d, %d)\n", r, g, b);
    } else {
      LoRa.println("ERR:INVALID_RGB_FORMAT");
    }
  }
  else if (msg.equalsIgnoreCase("PING")) {
    LoRa.println("PONG");
    Serial.println("Replied PONG");
  }
  else if (msg.equalsIgnoreCase("GET_TEMP")) {
    float cpuTemp = temperatureRead();
    LoRa.print("CPU_TEMP:");
    LoRa.println(cpuTemp, 1);
  }
  else if (msg.equalsIgnoreCase("OFF")) {
    setColor(0, 0, 0);
    LoRa.println("RGB_OK:0,0,0");
  }
  else {
    LoRa.print("UNKNOWN_CMD:");
    LoRa.println(msg);
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("Starting ESP32-C3 LoRa Node...");

  pixel.begin();
  pixel.clear();

  // Startup RGB Self-Test
  setColor(255, 0, 0); delay(300);
  setColor(0, 255, 0); delay(300);
  setColor(0, 0, 255); delay(300);
  setColor(0, 0, 0);

  // Initialize HardwareSerial for DX-LR22 868MHz
  LoRa.begin(LORA_BAUD, SERIAL_8N1, LORA_RX, LORA_TX);
  delay(100);

  LoRa.println("ESP32 READY");
  Serial.println("ESP32 Ready. DX-LR22 LoRa active.");
}

void loop() {
  // Periodic CPU temperature telemetry transmission
  if (millis() - lastTemp >= TEMP_INTERVAL) {
    lastTemp = millis();

    float cpuTemp = temperatureRead();

    LoRa.print("CPU_TEMP:");
    LoRa.println(cpuTemp, 1);

    Serial.print("Telemetry sent: CPU_TEMP:");
    Serial.println(cpuTemp, 1);
  }

  // Non-blocking LoRa serial command reader
  while (LoRa.available()) {
    char c = (char)LoRa.read();
    if (c == '\n') {
      processCommand(inputBuffer);
      inputBuffer = "";
    } else if (c != '\r') {
      inputBuffer += c;
    }
  }
}
