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
const unsigned long TEMP_INTERVAL = 5000; // Send telemetry every 5 seconds

String inputBuffer = "";

// LED animation state variables
enum LedMode { MODE_SOLID, MODE_RAINBOW, MODE_BLINK, MODE_STROBE };
LedMode currentMode = MODE_SOLID;

unsigned long lastEffectUpdate = 0;
uint16_t rainbowHue = 0;
bool blinkState = false;
int blinkR = 255, blinkG = 0, blinkB = 0;

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

      currentMode = MODE_SOLID;
      setColor(r, g, b);
      LoRa.printf("RGB_OK:%d,%d,%d\n", r, g, b);
      Serial.printf("RGB updated to (%d, %d, %d)\n", r, g, b);
    } else {
      LoRa.println("ERR:INVALID_RGB_FORMAT");
    }
  }
  else if (msg.startsWith("EFFECT:")) {
    String effect = msg.substring(7);
    effect.toUpperCase();
    effect.trim();

    if (effect == "RAINBOW") {
      currentMode = MODE_RAINBOW;
      LoRa.println("EFFECT_OK:RAINBOW");
    } else if (effect == "BLINK") {
      currentMode = MODE_BLINK;
      blinkR = 255; blinkG = 0; blinkB = 0;
      LoRa.println("EFFECT_OK:BLINK");
    } else if (effect == "STROBE") {
      currentMode = MODE_STROBE;
      LoRa.println("EFFECT_OK:STROBE");
    } else if (effect == "OFF" || effect == "SOLID") {
      currentMode = MODE_SOLID;
      setColor(0, 0, 0);
      LoRa.println("EFFECT_OK:SOLID");
    } else {
      LoRa.print("ERR:UNKNOWN_EFFECT:");
      LoRa.println(effect);
    }
  }
  else if (msg.startsWith("PING")) {
    // If command is PING:<seq> return PONG:<seq>
    if (msg.startsWith("PING:")) {
      String seq = msg.substring(5);
      LoRa.print("PONG:");
      LoRa.println(seq);
    } else {
      LoRa.println("PONG");
    }
    Serial.println("Replied PONG");
  }
  else if (msg.equalsIgnoreCase("GET_TEMP")) {
    float cpuTemp = temperatureRead();
    LoRa.print("CPU_TEMP:");
    LoRa.println(cpuTemp, 1);
  }
  else if (msg.equalsIgnoreCase("SYS_INFO")) {
    float cpuTemp = temperatureRead();
    unsigned long uptimeSec = millis() / 1000;
    uint32_t freeHeap = ESP.getFreeHeap();

    LoRa.printf("SYS_INFO:TEMP=%.1f,UPTIME=%lu,HEAP=%u\n", cpuTemp, uptimeSec, freeHeap);
    Serial.printf("SYS_INFO sent: Temp=%.1f C, Uptime=%lu s, Heap=%u bytes\n", cpuTemp, uptimeSec, freeHeap);
  }
  else if (msg.equalsIgnoreCase("RESET")) {
    LoRa.println("SYS_RESETTING");
    delay(200);
    ESP.restart();
  }
  else if (msg.equalsIgnoreCase("OFF")) {
    currentMode = MODE_SOLID;
    setColor(0, 0, 0);
    LoRa.println("RGB_OK:0,0,0");
  }
  else {
    LoRa.print("UNKNOWN_CMD:");
    LoRa.println(msg);
  }
}

void updateLedEffects() {
  unsigned long now = millis();

  if (currentMode == MODE_RAINBOW) {
    if (now - lastEffectUpdate >= 20) { // ~50 FPS rainbow speed
      lastEffectUpdate = now;
      rainbowHue += 256; // advance color
      pixel.setPixelColor(0, pixel.gamma32(pixel.ColorHSV(rainbowHue)));
      pixel.show();
    }
  }
  else if (currentMode == MODE_BLINK) {
    if (now - lastEffectUpdate >= 500) { // 1 Hz toggle
      lastEffectUpdate = now;
      blinkState = !blinkState;
      if (blinkState) {
        setColor(blinkR, blinkG, blinkB);
      } else {
        setColor(0, 0, 0);
      }
    }
  }
  else if (currentMode == MODE_STROBE) {
    if (now - lastEffectUpdate >= 80) { // Fast strobe
      lastEffectUpdate = now;
      blinkState = !blinkState;
      if (blinkState) {
        setColor(255, 255, 255);
      } else {
        setColor(0, 0, 0);
      }
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("Starting ESP32-C3 LoRa Node v2...");

  pixel.begin();
  pixel.clear();

  // Startup RGB Self-Test
  setColor(255, 0, 0); delay(200);
  setColor(0, 255, 0); delay(200);
  setColor(0, 0, 255); delay(200);
  setColor(0, 0, 0);

  // Initialize HardwareSerial for DX-LR22 868MHz
  LoRa.begin(LORA_BAUD, SERIAL_8N1, LORA_RX, LORA_TX);
  delay(100);

  LoRa.println("ESP32 READY");
  Serial.println("ESP32 Ready. DX-LR22 LoRa active.");
}

void loop() {
  // Update non-blocking LED animation modes
  updateLedEffects();

  // Periodic telemetry transmission (Temperature, Uptime, Heap)
  if (millis() - lastTemp >= TEMP_INTERVAL) {
    lastTemp = millis();

    float cpuTemp = temperatureRead();
    unsigned long uptimeSec = millis() / 1000;
    uint32_t freeHeap = ESP.getFreeHeap();

    LoRa.printf("CPU_TEMP:%.1f\n", cpuTemp);
    Serial.printf("Telemetry sent: CPU_TEMP:%.1f | Uptime:%lu s | Heap:%u B\n", cpuTemp, uptimeSec, freeHeap);
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
