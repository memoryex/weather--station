/*
  RFID ADAX v1.4 - Optimized & Rate-Limited
  - ThingSpeak library with 15s rate-limit queue
  - Non-blocking 5s relay/LED timer (retriggerable)
  - Scheduled restart at 00:00 (NTP)
  - Verbose Serial logging
*/

#include <ESP8266WiFi.h>
#include <rdm630.h>
#include <ArduinoOTA.h>
#include <WiFiUdp.h>
#include <NTPClient.h>
#include <ThingSpeak.h>
#include <deque> // For data queueing

// --- Configuration ---
const char* WIFI_SSID = "Adax_Sandelys";
const char* WIFI_PASS = "noriu42interneto";

// ThingSpeak Configuration
const unsigned long TS_CHANNEL_ID = 0; // REPLACE WITH ACTUAL ID
const char* TS_API_KEY = "9RO3MUI3LNTMQ0WO";
const unsigned long TS_SEND_INTERVAL = 16000; // 16 seconds to be safe (15s limit)

// Pin Definitions (Wemos D1 Mini)
const int PIN_RFID0_RX = 5;  // D1
const int PIN_RFID1_RX = 4;  // D2
const int PIN_ALARM    = 0;  // D3
const int PIN_RELAY    = 12; // D6
const int PIN_LED      = 13; // D7

const unsigned long CODE_READ_DELAY = 1000;
const unsigned long RELAY_ACTIVE_DURATION = 5000; // 5 seconds

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

// --- Queue Structure ---
struct TSData {
  int field;
  String value;
};
std::deque<TSData> tsQueue;

// --- Globals ---
WiFiClient client;
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 7200); // UTC+2

rdm630 rfid0(PIN_RFID0_RX, 0);
rdm630 rfid1(PIN_RFID1_RX, 0);

unsigned long nextCodeReadTime = 0;
unsigned long relayOffTime = 0;
unsigned long lastTSSendTime = 0;
bool restartedToday = false;

void logMessage(String msg) {
  Serial.print("[" + timeClient.getFormattedTime() + "] ");
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

void processTSQueue() {
  if (tsQueue.empty()) return;

  unsigned long now = millis();
  if (now - lastTSSendTime >= TS_SEND_INTERVAL) {
    TSData data = tsQueue.front();
    tsQueue.pop_front();

    logMessage("[TS] Siunciama is eiles (liko: " + String(tsQueue.size()) + "): Field" + String(data.field) + " = " + data.value);

    int response = ThingSpeak.writeField(TS_CHANNEL_ID, data.field, data.value, TS_API_KEY);
    if (response == 200) {
      logMessage("[TS] Issiusta sekmingai.");
    } else {
      logMessage("[TS] Klaida! Kodas: " + String(response));
      // Optionally put it back if it's a temporary error, but let's keep it simple for now
    }
    lastTSSendTime = millis();
  }
}

void enqueueToTS(int field, String value) {
  tsQueue.push_back({field, value});
  logMessage("[TS] Prideta i eile: Field" + String(field) + " = " + value + " (Eiles ilgis: " + String(tsQueue.size()) + ")");
}

void processRFID(rdm630 &rfid, int fieldNum, String direction) {
  if (rfid.available() > 0) {
    unsigned long code = readRFID(rfid);
    logMessage("TAG NUSKAITYTAS (" + direction + "): " + String(code));

    if (millis() < nextCodeReadTime) {
      logMessage("...praleidziama (debounce)");
      return;
    }

    if (isAuthorized(code)) {
      logMessage(">>> PRIEIGA SUTEIKTA (" + direction + ") <<<");

      // Immediate Relay & LED (retriggerable)
      relayOffTime = millis() + RELAY_ACTIVE_DURATION;

      // Enqueue for background sending
      enqueueToTS(fieldNum, String(code) + " " + direction);

      nextCodeReadTime = millis() + CODE_READ_DELAY;
    } else {
      logMessage("!!! NEATPAZINTAS ID !!!");
      for (int i = 0; i < 3; i++) {
        digitalWrite(PIN_LED, HIGH); delay(100);
        digitalWrite(PIN_LED, LOW); delay(100);
      }
    }
  }
}

void checkAlarm() {
  if (digitalRead(PIN_ALARM) == LOW) {
    logMessage("!!! ALARM !!!");
    enqueueToTS(3, "ALARM");
    for (int i = 0; i < 5; i++) {
      digitalWrite(PIN_LED, HIGH); delay(500);
      digitalWrite(PIN_LED, LOW); delay(500);
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n===============================================");
  Serial.println("      ADAX RFID EL.BARAS v1.4 RATE-LIMITED     ");
  Serial.println("===============================================");

  pinMode(PIN_RELAY, OUTPUT);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_ALARM, INPUT);
  digitalWrite(PIN_RELAY, HIGH);
  digitalWrite(PIN_LED, LOW);

  for (int i = 0; i < 4; i++) {
    digitalWrite(PIN_LED, HIGH); delay(100);
    digitalWrite(PIN_LED, LOW); delay(100);
  }

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("[WIFI] Jungiamasi prie " + String(WIFI_SSID));
  int count = 0;
  while (WiFi.status() != WL_CONNECTED && count < 60) {
    digitalWrite(PIN_LED, !digitalRead(PIN_LED));
    delay(500); Serial.print("."); count++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] PRISIJUNGTA! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n[WIFI] Nepavyko prisijungti.");
  }

  ArduinoOTA.setHostname("ADAX RFID EL.BARAS v1.4");
  ArduinoOTA.begin();

  timeClient.begin();
  rfid0.begin();
  rfid1.begin();
  ThingSpeak.begin(client);

  logMessage("SISTEMA PARUOSTA.");
}

void loop() {
  ArduinoOTA.handle();
  timeClient.update();

  // Non-blocking output control
  if (millis() < relayOffTime) {
    digitalWrite(PIN_RELAY, LOW);
    digitalWrite(PIN_LED, HIGH);
  } else {
    digitalWrite(PIN_RELAY, HIGH);
    digitalWrite(PIN_LED, LOW);
  }

  // Process RFID inputs
  processRFID(rfid0, 1, "IN");
  processRFID(rfid1, 2, "OUT");

  // Process ThingSpeak Queue (Limited to 1 send every 16s)
  processTSQueue();

  checkAlarm();

  // Daily Restart at 00:00:00
  if (timeClient.getHours() == 0 && timeClient.getMinutes() == 0 && timeClient.getSeconds() == 0) {
    if (!restartedToday) {
      restartedToday = true;
      logMessage("RESTARTAS (00:00)...");
      ThingSpeak.writeField(TS_CHANNEL_ID, 3, "DAILY_RESTART", TS_API_KEY);
      delay(2000);
      ESP.restart();
    }
  } else {
    restartedToday = false;
  }
}
