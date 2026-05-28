/*
  RFID ADAX v1.2 - Optimized
  - Removed Blynk dependencies
  - Consolidated RFID handling logic
  - Optimized authorized ID check with binary search
  - Cleaned up redundant code and comments
  - Streamlined ThingSpeak reporting
*/

#include <ESP8266WiFi.h>
#include <rdm630.h>
#include <ArduinoOTA.h>
#include <WiFiUdp.h>
#include <NTPClient.h>

// --- Configuration ---
const char* WIFI_SSID = "Adax_Sandelys";
const char* WIFI_PASS = "noriu42interneto";
const char* THINGSPEAK_SERVER = "api.thingspeak.com";
const char* API_KEY = "9RO3MUI3LNTMQ0WO";

// Pin Definitions (Wemos D1 Mini)
const int PIN_RFID0_RX = 5;  // D1
const int PIN_RFID1_RX = 4;  // D2
const int PIN_ALARM    = 0;  // D3
const int PIN_RELAY    = 12; // D6
const int PIN_LED      = 13; // D7

const unsigned long CODE_READ_DELAY = 1000;
const unsigned long RESTART_INTERVAL = 86400000; // 24 hours

// Authorized RFID Tags (Sorted for Binary Search)
const unsigned long AUTHORIZED_TAGS[] = {
  924047, 1565631, 2026094, 2033581, 2053496, 2338261, 2344680, 2757837, 3572993, 5627203,
  5920382, 5930615, 5934674, 5936677, 5945973, 5957645, 5987746, 6009123, 6010281, 6020181,
  6021150, 6034903, 6067604, 6076603, 6084435, 6146163, 6254271, 6387637, 6387644, 6387693,
  6387698, 6387703, 6387742, 6387759, 7462938, 7633284, 7952707, 7976256, 8162025, 8226572,
  8235383, 8529483, 8847820, 8867111, 8885224, 8899445, 8921255, 8933716, 8941478, 8958241,
  8964939, 8978869, 9262529, 10799104, 11201037, 11273795, 11287111, 11292087, 11301202,
  11304914, 11309806, 11310829, 11329792, 11338836, 11344678, 11351350, 11352517, 11358236,
  11360994, 11367448, 11379480, 11382564, 11400465, 11411173, 14364982, 15130475, 15130496
};
const int AUTHORIZED_TAGS_COUNT = sizeof(AUTHORIZED_TAGS) / sizeof(AUTHORIZED_TAGS[0]);

// --- Globals ---
WiFiClient client;
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 7200); // UTC+2

rdm630 rfid0(PIN_RFID0_RX, 0);
rdm630 rfid1(PIN_RFID1_RX, 0);

unsigned long nextCodeReadTime = 0;
unsigned long lastRestartMillis = 0;

void logMessage(String msg) {
  Serial.print(timeClient.getFormattedTime());
  Serial.print(" - ");
  Serial.println(msg);
}

bool isAuthorized(unsigned long code) {
  int low = 0;
  int high = AUTHORIZED_TAGS_COUNT - 1;
  while (low <= high) {
    int mid = low + (high - low) / 2;
    if (AUTHORIZED_TAGS[mid] == code) return true;
    if (AUTHORIZED_TAGS[mid] < code) low = mid + 1;
    else high = mid - 1;
  }
  return false;
}

unsigned long readRFID(rdm630 &rfid) {
  byte data[6];
  byte length;
  rfid.getData(data, length);

  unsigned long result =
    ((unsigned long int)data[1] << 24) +
    ((unsigned long int)data[2] << 16) +
    ((unsigned long int)data[3] << 8) +
    data[4];

  return result;
}

void sendToThingSpeak(String field, String value) {
  if (client.connect(THINGSPEAK_SERVER, 80)) {
    client.print("GET /update?api_key=");
    client.print(API_KEY);
    client.print("&");
    client.print(field);
    client.print("=");
    client.print(value);
    client.println(" HTTP/1.1");
    client.print("Host: ");
    client.println(THINGSPEAK_SERVER);
    client.println("Connection: close");
    client.println();
    logMessage("Sent: " + field + "=" + value);
  } else {
    logMessage("ThingSpeak connection failed!");
  }
}

void processRFID(rdm630 &rfid, int fieldNum, String direction) {
  if (rfid.available() > 0) {
    unsigned long code = readRFID(rfid);
    logMessage("RFID Scanned (" + direction + "): " + String(code));

    if (millis() < nextCodeReadTime) {
      logMessage("Ignored (delay active)");
      return;
    }

    if (isAuthorized(code)) {
      logMessage("ACCESS GRANTED (" + direction + ")");
      digitalWrite(PIN_RELAY, LOW);
      digitalWrite(PIN_LED, HIGH);

      sendToThingSpeak("field" + String(fieldNum), String(code) + " " + direction);

      delay(250);
      digitalWrite(PIN_RELAY, HIGH);
      digitalWrite(PIN_LED, LOW);
      nextCodeReadTime = millis() + CODE_READ_DELAY;
    } else {
      logMessage("ACCESS DENIED!");
      for (int i = 0; i < 2; i++) {
        digitalWrite(PIN_LED, HIGH); delay(150);
        digitalWrite(PIN_LED, LOW); delay(150);
      }
    }
  }
}

void checkAlarm() {
  if (digitalRead(PIN_ALARM) == LOW) {
    logMessage("ALARM BUTTON PRESSED!");
    sendToThingSpeak("field3", "ALARM");
    for (int i = 0; i < 5; i++) {
      digitalWrite(PIN_LED, HIGH); delay(500);
      digitalWrite(PIN_LED, LOW); delay(500);
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_RELAY, OUTPUT);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_ALARM, INPUT);

  digitalWrite(PIN_RELAY, HIGH); // Relay off

  // Initial blink
  for (int i = 0; i < 4; i++) {
    digitalWrite(PIN_LED, HIGH); delay(80);
    digitalWrite(PIN_LED, LOW); delay(80);
  }

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    digitalWrite(PIN_LED, !digitalRead(PIN_LED));
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected! IP: " + WiFi.localIP().toString());

  ArduinoOTA.setHostname("ADAX RFID EL.BARAS v1.2");
  ArduinoOTA.begin();

  timeClient.begin();
  rfid0.begin();
  rfid1.begin();

  logMessage("System ready. Free Heap: " + String(ESP.getFreeHeap()) + " B");
}

void loop() {
  ArduinoOTA.handle();
  timeClient.update();

  processRFID(rfid0, 1, "IN");
  processRFID(rfid1, 2, "OUT");

  checkAlarm();

  // Daily restart
  if (millis() - lastRestartMillis > RESTART_INTERVAL) {
    logMessage("Scheduled restart...");
    sendToThingSpeak("field3", "RESTART");
    delay(1000);
    ESP.restart();
  }
}
