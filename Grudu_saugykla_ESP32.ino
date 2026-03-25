/*
================================================================================
| GRŪDŲ SAUGYKLOS VALDIKLIO PROGRAMINĖ ĮRANGA - v4.1.3b
================================================================================

PROJEKTO APRAŠYMAS:
Ši programa skirta valdyti ir stebėti grūdų saugyklos aplinkos parametrus,
naudojant ESP32 valdiklį ir Blynk Edgent debesies platformą. Stebimi parametrai:
DS18B20 temperatūros jutikliai (3 magistralės), SHT45 temperatūra/drėgmė,
akumuliatoriaus įtampa/įkrova, CPU temperatūra. Taip pat valdomi 4 relės moduliai.
Duomenys taip matomi per LCD ST7920 128x64 grafinį ekranėlį.

CPU TEMPERATŪRA (Pastovaus 53°C)
-----------------------------
- Matuojama vidiniu ESP32 diodais pagrįstu jutikliu (funkcija 'temprature_sens_read').
- Temperatūra yra koreguojama, naudojant poslinkį (offset): (RAW_F - 32) / 1.8 - 17.0.
- 50°C - 60°C diapazonas yra normalus ESP32 procesoriui veikiant su aktyviu Wi-Fi.

PROGRAMOS ALGORITMAS:
-----------------------------
 - Startuojant valdikliui įjungimas MOSFET stiprintuvas, nuskaitomi jutiklių DS18B20 adresai, kiek jutiklių yra magistralėje ir temperatūros parodymai. Atvaizduojama LCD ekranėlyje, siunčiama dignostika į Blynk terminalą(serverį), Serial monitor.
 - Patikrina ar pajungtas SHT45 jutiklis, nuskaitoma temperatūros ir dregmės parodymai.
 - Jungiamasi prie Wi-Fi, sėkmingai prisijungus jungiamasi prie Blynk serverio ir tikrinamas prisijungas prie ThingSpeak serverio. Nepavykus kartojama.
 - **RELIŲ BŪSENOS ATKŪRIMAS (Atnaujinimas):** Po sėkmingo prisijungimo prie Blynk serverio, valdiklis inicijuoja sinchronizavimą, prašydamas serverio atsiųsti paskutines žinomas V3, V9, V13, V14 reikšmes. Šis mechanizmas užtikrina, kad relių fizinė būsena būtų atkurta į paskutinę vartotojo nustatytą būseną (išsaugota Blynk serveryje), nepaisant trumpalaikių tinklo nutrūkimų, taip išvengiant netyčinio relių išsijungimo.
 - Valdikliui pasikrovus į to pačio ciklo eigą, kas 5 sekundžių nuskaitinėjama jutiklių parodymai, atnaujinamas LCD ekranėlio parodymai.
 - Kas 30 sekundžių atnaujinama visų jutiklių parodymai, siunčiama į Blynk terminalą(serverį), Serial monitor.
 - Kas 2 minutes siunčiama į ThingSpeak serverį.
 - **Užduočių Stebėjimo Laikmatis (Watchdog Timer, WDT):** Šis mechanizmas yra aktyvuojamas tik tada, kai dingsta tinklo ryšys (Wi-Fi arba Blynk), siekiant užtikrinti sistemos persikrovimą, jei nepavyksta prisijungti per 60 sekundžių. Normaliu veikimo režimu WDT yra išjungtas (remiamasi numatytuoju ESP32 Task WDT).
 - Valdiklis automatiškai kiekvieną parą 4:00 persikrauna automatiškai, išvengti atminties perpildymo.

 PATAISYTOS KLAIDOS, PATOBULINTA:
-----------------------------
 - 4.0.1 - ciklo antnaujinimo metu išlaikoma rėlės busena pagal duotą komandą iš Blynk.
 - 4.0.2 - sutvarkytas LCD ekranėlyje eilutės pastumimas, kai simboliai viršija eilutę. Pridėta WDT persikrovimo priežasties parodymas, pridėta "up-time" valdyklio laikmatis.
 - 4.0.3 - pakeista automatinis persikrovimo laikas vietoje kas 24h(4:00), nustatyta kas 7 paras(4:00 sekmadienį)
 - 4.0.4 - pridėta DS18B20 jutiklių rezoliucijos nustatymas.
 - 4.1.0 - pridėta freeRTOS, atskirtas CPU dviejų barnduolių darbas.
 - 4.1.1 - Automatinis R1, R2 išjungimo valdymas, esant lauko drėgmei didesnei, nei 80 proc. Pataisyta BLYNK komunikacija
 - 4.1.2 - Nustatytas kasdienis automatinis perkrovimas 4:00 ryto, greižtesnis prie wifi prisijungimo tikrinimas
 - 4.1.3 - Pridėta funkcija Blynk terminal komandinė eilutė. "ds18b20" - parodo jutiklių adresus ir temperatūros reikšmes pateikus užklausą.
================================================================================
| GPIO (Įvesties/Išvesties) JUNGTYS
================================================================================

1. RELĖS VALDYMAS (LOW = ON, HIGH = OFF)
| Kintamasis | GPIO Pin | Blynk V-Pin | Paskirtis | Valdymo Logika | Blynk Atvaizdavimas (1 = ON) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Relay1 | 26 | V3 | Ventiliatorius (V) | Standartinė (LOW=ON) | 1 $\to$ ON (LOW) |
| Relay2 | 25 | V9 | Kompensacinis (K) | Standartinė (LOW=ON) | 1 $\to$ ON (LOW) |
| Relay3 | 14 | V13 | Relė R3 | Atvirkštinė (LOW=ON) | 1 $\to$ OFF (HIGH) |
| Relay4 | 13 | V14 | Relė R4 | Atvirkštinė (LOW=ON) | 1 $\to$ OFF (HIGH) |

2. TEMPERATŪROS MAGISTRALĖS (DS18B20)
| Kintamasis | GPIO Pin | Paskirtis | Ryšio Tipas |
| :---: | :---: | :---: | :---: |
| ONE_WIRE_BUS1 | 32 | 130T (Bus 1) | OneWire |
| ONE_WIRE_BUS2 | 33 | 250T (Bus 2) | OneWire |
| ONE_WIRE_BUS3 | 14 | 100T (Bus 3) | OneWire |
| BUS_PWR_CTRL | 27 | MOSFET maitinimas DS18B20 (LOW = ON) | Digital Out |

3. KITI JUTIKLIAI IR SISTEMA
| Kintamasis | GPIO Pin | Paskirtis | Tipas |
| :---: | :---: | :---: | :---: |
| Nėra | 21, 22 | SHT45 Temp/Drėgmė | I2C (SDA=21, SCL=22) |
| BAT_ADC_PIN | 34 | Baterijos Įtampa | Analog In |
| PIN_R | 15 | RGB LED Raudona | PWM Out |
| PIN_G | 2 | RGB LED Žalia | PWM Out |
| PIN_B | 4 | RGB LED Mėlyna | PWM Out |

================================================================================
*/

// ===== BLYNK KONFIGŪRACIJA (Perkelta iš secrets.h) =====
#define BLYNK_TEMPLATE_ID "TMPL49hJVrt6h"
#define BLYNK_TEMPLATE_NAME "Bokstai"
#define BLYNK_FIRMWARE_VERSION "4.1.3b" // ATNAUJINTA versija
#define BLYNK_PRINT Serial
#define APP_DEBUG

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClient.h>
#include <BlynkEdgent.h>
#include <DallasTemperature.h>
#include <OneWire.h>
#include <ThingSpeak.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <U8g2lib.h>
#include "esp_task_wdt.h"
#include <time.h>
#include <SPI.h>
#include "esp_heap_caps.h"

// ===== FreeRTOS DVIEJŲ BRANDUOLIŲ KONFIGŪRACIJA =====
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

TaskHandle_t TimerTaskHandle;
SemaphoreHandle_t networkMutex;
SemaphoreHandle_t serialMutex;
SemaphoreHandle_t stateMutex; // NAUJAS mutex bendrinamiems kintamiesiems


// Užduotis, kuri veiks Core 1 ir vykdys BlynkTimer
void timerTask(void *pvParameters);


// BŪTINI FAILAI
#include "images.h"
#include "secrets.h"


// ===== PIN'AI =====
#define ONE_WIRE_BUS1 32
#define ONE_WIRE_BUS2 33
#define ONE_WIRE_BUS3 14
#define ONE_WIRE_BUS4 16 // Nauja magistralė ant GPIO 16

#define Relay1 26 // V (Ventiliatorius)
#define Relay2 25 // K (Kompensacinis)
#define Relay3 13  // R3
#define Relay4 12 // R4

#define BUS_PWR_CTRL 27
#define BAT_ADC_PIN 34

#define PIN_R 15
#define PIN_G 2
#define PIN_B 4

// ===== Globals =====
BlynkTimer timer;
WidgetTerminal terminal(V2);
bool shtOK = false;

// ===== BLYNK RELĖS BŪSENOS KINTAMIEJI (SVARBU: Išlaikyti po atsijungimo) =====
// Šie kintamieji saugo paskutinę pageidaujamą Blynk pinų būseną (0/1).
int desiredRelay1State = 0;
int desiredRelay2State = 0;
int desiredRelay3State = 0;
int desiredRelay4State = 0;


// ===== Dallas =====
OneWire wire1(ONE_WIRE_BUS1);
OneWire wire2(ONE_WIRE_BUS2);
OneWire wire3(ONE_WIRE_BUS3);
OneWire wire4(ONE_WIRE_BUS4);

DallasTemperature sensors1(&wire1, BUS_PWR_CTRL);
DallasTemperature sensors2(&wire2, BUS_PWR_CTRL);
DallasTemperature sensors3(&wire3, BUS_PWR_CTRL);
DallasTemperature sensors4(&wire4, BUS_PWR_CTRL);

int numberOfDevices1 = 0, numberOfDevices2 = 0, numberOfDevices3 = 0, numberOfDevices4 = 0;

// ===== SHT45 =====
Adafruit_SHT4x sht45;

// ===== ThingSpeak ir WiFi klientas =====
WiFiClient client;

// ===== Automatinio režimo nustatymai =====
bool autoHumidityEnabled = false; // Auto isjungimas pagal dregme

// ===== LCD Scroll / Grupavimo struktūros =====
struct ScrollLine {
  String text;
  int offset = 0;
  bool active = false;
  unsigned long lastMove = 0;
};

enum { IDX_130 = 0, IDX_250 = 1, IDX_100 = 2, IDX_DT = 3, IDX_RELAYS = 4, MAX_SCROLL_LINES = 5 };
ScrollLine scrollLines[MAX_SCROLL_LINES];

static const uint16_t DS_CONV_DELAY_MS = 1500;
static const uint8_t DS_RETRY_COUNT = 3;
const int SENSORS_PER_LINE = 8;
int currentSensorGroup[3] = {0, 0, 0};
unsigned long lastGroupChangeTime = 0;
const unsigned long GROUP_CHANGE_INTERVAL = 10000;

float sensorValues1[8];
float sensorValues2[8];
float sensorValues3[8];
float sensorValues4[8];

float currentShtTemp = NAN;
float currentShtHum = NAN;
float currentVbat = NAN;
int currentBatPercent = 0;
float currentCpuTemp = NAN;

extern "C" uint8_t temprature_sens_read();

#define R1_DIV 100000.0
#define R2_DIV 82000.0

float readCPUTempC() {
  float rawC = (temprature_sens_read() - 32.0) / 1.8;
  return rawC - 17.0;
}
float readBatteryVoltage() {
  const int SAMPLES = 10;
  long sum = 0;
  for (int i = 0; i < SAMPLES; i++) sum += analogRead(BAT_ADC_PIN);
  float raw = sum / (float)SAMPLES;
  float v_adc = (raw / 4095.0) * 3.3;
  float v_bat = v_adc * (R1_DIV + R2_DIV) / R2_DIV * 1.028;
  if (v_bat < 2.0 || v_bat > 5.5) return NAN;
  return v_bat;
}
int voltageToPercent(float vbat) {
  if (vbat >= 4.20) return 100;
  if (vbat <= 3.00) return 0;
  return (int)((vbat - 3.00) * 100.0 / (4.20 - 3.00));
}

U8G2_ST7920_128X64_F_HW_SPI u8g2(U8G2_R0, 5, U8X8_PIN_NONE);

void logMessage(const String& msg) {
  if (xSemaphoreTake(serialMutex, portMAX_DELAY) == pdTRUE) {
    Serial.println(msg);
    terminal.println(msg);
    terminal.flush();
    xSemaphoreGive(serialMutex);
  }
}

// ===== LED Valdymo funkcijos =====
void setRGB(uint8_t r, uint8_t g, uint8_t b) {
  analogWrite(PIN_R, 255 - r);
  analogWrite(PIN_G, 255 - g);
  analogWrite(PIN_B, 255 - b);
}
void rgbOff() { setRGB(0, 0, 0); }
void rgbStartupSequence() {
  delay(100); setRGB(255, 0, 0); delay(1000);
  setRGB(0, 255, 0); delay(1000);
  setRGB(0, 0, 255); delay(1000);
  rgbOff();
}
void rgbSendResult(bool ok) {
  if (ok) setRGB(0, 255, 0);
  else setRGB(255, 0, 0);
}
void rgbSending() { setRGB(0, 0, 255); }

void rgbBlink(bool onStatus) {
    if (onStatus) {
        setRGB(255, 0, 0);
    } else {
        setRGB(0, 255, 0);
    }
    timer.setTimer(150, rgbOff, 1);
}

void rgbFadeLoop() {
  static int val = 0; static int dir = 1; static unsigned long lastUpdate = 0;
  unsigned long now = millis();
  if (now - lastUpdate >= 20) {
    lastUpdate = now; val += dir;
    if (val >= 255) { val = 255; dir = -1; }
    if (val <= 0) { val = 0; dir = 1; }
    setRGB(0, 0, val);
  }
}
void rgbWiFiWait() { setRGB(255, 0, 0); }
void rgbIdle() { rgbFadeLoop(); }

// ===== LCD Valdymo funkcijos =====
void prepareLineScroll(int idx, const String& txt) {
  if (idx < 0 || idx >= MAX_SCROLL_LINES) return;
  ScrollLine& ln = scrollLines[idx];

  // Nustatome, ar eilutė yra aktyvi (per ilga)
  u8g2.setFont(u8g2_font_6x12_t_cyrillic);
  int width = u8g2.getStrWidth(txt.c_str());
  int dispW = u8g2.getDisplayWidth();
  ln.active = (width > dispW - 2);

  // Atstatome poziciją ir laikmatį TIK JEI tekstas pasikeitė
  if (ln.text != txt) {
    ln.text = txt;
    ln.offset = 0;
    ln.lastMove = millis();
  }
}

void drawScrollLine(int y, ScrollLine& ln) {
  u8g2.setFont(u8g2_font_6x12_t_cyrillic);
  u8g2.setFontMode(1);
  int width = u8g2.getStrWidth(ln.text.c_str());
  int dispW = u8g2.getDisplayWidth();

  const int X_OFFSET = 0;
  const unsigned long JUMP_INTERVAL = 10000; // 10 sekundžių intervalas

  if (!ln.active) {
    u8g2.drawStr(X_OFFSET, y, ln.text.c_str());
    return;
  }

  unsigned long now = millis();
  if (now - ln.lastMove > JUMP_INTERVAL) {
    ln.lastMove = now;

    // Pastumiame offset per ekrano plotį
    ln.offset += dispW;

    // Jei offset'as didesnis už teksto ilgį, grįžtame į pradžią
    if (ln.offset >= width) {
      ln.offset = 0;
    }
  }
  u8g2.drawStr(X_OFFSET - ln.offset, y, ln.text.c_str());
}
void drawWifiIndicator(int x, int y) {
  long rssi = WiFi.RSSI();
  int level = 0;
  if (rssi > -60) level = 4;
  else if (rssi > -70) level = 3;
  else if (rssi > -80) level = 2;
  else if (rssi > -90) level = 1;

  const int h1 = 2, h2 = 4, h3 = 6, h4 = 8;
  const int x_gap = 2;

  if (level >= 1) u8g2.drawBox(x, y - h1, 1, h1);
  if (level >= 2) u8g2.drawBox(x + x_gap, y - h2, 1, h2);
  if (level >= 3) u8g2.drawBox(x + x_gap * 2, y - h3, 1, h3);
  if (level >= 4) u8g2.drawBox(x + x_gap * 3, y - h4, 1, h4);
}
const int LCD_HEIGHT = 64;

void drawBatteryIndicator(int x, int y, int percent) {
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;

    int w = 15;
    int h = 7;
    int cap_w = 2;

    u8g2.drawRFrame(x, y, w, h, 1);
    u8g2.drawBox(x + w, y + 2, cap_w, h - 4);

    int fill_width = (int)((w - 4) * (percent / 100.0));
    u8g2.drawBox(x + 2, y + 2, fill_width, h - 4);
}

// R1 ir R2 fizinio statuso atvaizdavimas (LOW=ON, HIGH=OFF)
// R3 ir R4 fizinio statuso atvaizdavimas (HIGH=ON, LOW=OFF)
String getRelayStatus(int pin) {
    if (pin == Relay3 || pin == Relay4) {
        return digitalRead(pin) == HIGH ? "ON" : "OFF";
    }
    return digitalRead(pin) == LOW ? "ON" : "OFF";
}


void drawLCD() {
  if (millis() - lastGroupChangeTime > GROUP_CHANGE_INTERVAL) {
    lastGroupChangeTime = millis();

    auto updateGroup = [](int& group, int devices) {
      int maxGroups = (devices + SENSORS_PER_LINE - 1) / SENSORS_PER_LINE;
      group = (group + 1) % (maxGroups > 0 ? maxGroups : 1);
    };

    // Čia visada bus rodoma 1 grupė, nes SENSORS_PER_LINE = 8
    updateGroup(currentSensorGroup[0], numberOfDevices1);
    updateGroup(currentSensorGroup[1], numberOfDevices2);
    updateGroup(currentSensorGroup[2], numberOfDevices3);
  }

  auto formatBusLine = [&](int busIndex, float* values, int devCount, const String& busLabel) -> String {
    String s = busLabel + ":";
    if (devCount == 0) return s + "Nera jutikliu";

    int startIdx = currentSensorGroup[busIndex] * SENSORS_PER_LINE;
    int endIdx = min(startIdx + SENSORS_PER_LINE, devCount);

    for (int i = startIdx; i < endIdx; i++) {
      s += String(i + 1) + ":";
      float v = values[i];
      s += ((v == DEVICE_DISCONNECTED_C || v == -127.0f || v == 85.0f || isnan(v)) ? "err" : String(v, 1) + "C");
      if (i < endIdx - 1) s += " ";
    }
    return s;
  };

  // Relės statusų eilutė
  String relayLine = String("V:") + getRelayStatus(Relay1) + " K:" + getRelayStatus(Relay2) +
                     " R3:" + getRelayStatus(Relay3) + " R4:" + getRelayStatus(Relay4);

  // Relės eilutė priskiriama slinkimui
  prepareLineScroll(IDX_RELAYS, relayLine);

  // Nustatome kitas slenkančias eilutes
  prepareLineScroll(IDX_130, formatBusLine(0, sensorValues1, numberOfDevices1, "130T"));
  prepareLineScroll(IDX_250, formatBusLine(1, sensorValues2, numberOfDevices2, "250T"));
  prepareLineScroll(IDX_100, formatBusLine(2, sensorValues3, numberOfDevices3, "100T"));

  // Lauko eilutė
  prepareLineScroll(IDX_DT, String("Laukas: ") + (isnan(currentShtTemp) ? "N/A" : String(currentShtTemp, 1) + "C") + " " + (isnan(currentShtHum) ? "" : String(currentShtHum, 1) + "%RH"));

  u8g2.firstPage();
  do {
    u8g2.setFont(u8g2_font_6x12_t_cyrillic);
    u8g2.setFontMode(1);

    // LINIJA 1 (Y=10): SISTEMA, ĮTAMPA, BŪSENA
    int y_pos = 10;
    u8g2.drawStr(0, y_pos, "Sistema:");
    u8g2.drawStr(50, y_pos, (String(currentVbat, 2) + "V").c_str());
    drawBatteryIndicator(95, y_pos - 7, currentBatPercent);
    drawWifiIndicator(118, y_pos);


    // LINIJA 2 (Y=19): RELĖS STATUSAS (SLENKANTI)
    y_pos += 9;
    drawScrollLine(y_pos, scrollLines[IDX_RELAYS]);


    // LINIJOS 3, 4, 5: JUTIKLIAI (SUTANKINTOS, SLENKANČIOS)
    y_pos += 9;
    drawScrollLine(y_pos, scrollLines[IDX_130]);
    y_pos += 9;
    drawScrollLine(y_pos, scrollLines[IDX_250]);
    y_pos += 9;
    drawScrollLine(y_pos, scrollLines[IDX_100]);

    // LINIJA 6: LAUKAS (PLATENĖ, SLENKANTI)
    y_pos += 9;
    drawScrollLine(y_pos, scrollLines[IDX_DT]);


    // LINIJA 8 (PASKUTINĖ): LAIKAS/BŪSENA
    time_t now = time(nullptr);
    struct tm tinfo;
    localtime_r(&now, &tinfo);
    char timebuf[32];

    if (tinfo.tm_year >= 100) {
      strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M", &tinfo);
    } else {
      if (WiFi.status() != WL_CONNECTED) {
        strcpy(timebuf, "WIFI: Atsijunges!");
      } else if (!Blynk.connected()) {
        strcpy(timebuf, "BLYNK: Jungiasi...");
      } else {
        strcpy(timebuf, "Laukia laikrodzio...");
      }
    }
    u8g2.drawStr(0, LCD_HEIGHT - 1, timebuf);

  } while (u8g2.nextPage());
}

// *************************************************************
// ********** DS18B20 ir Sensorika *****************************
// *************************************************************

int readBusAndPublishBlocking(DallasTemperature& bus, int devCount, float* values, int blynkBaseVpin, const char* labelPrefix, unsigned long tsChannel, const char* tsApiKey) {
    static const uint16_t DS_WAIT_MS = 750;

    digitalWrite(BUS_PWR_CTRL, LOW);
    delay(300);

    if (devCount <= 0) {
        logMessage(String(labelPrefix) + ": nėra jutiklių 🤷");
        digitalWrite(BUS_PWR_CTRL, HIGH);
        return 0;
    }
    int ok_total = 0;
    for (int i = 0; i < devCount && i < 8; i++) {
        float c = DEVICE_DISCONNECTED_C;
        bool success = false;

        for (uint8_t attempt = 0; attempt < DS_RETRY_COUNT; attempt++) {
            bus.requestTemperatures();
            delay(DS_WAIT_MS + 100);
            c = bus.getTempCByIndex(i);

            if (c != DEVICE_DISCONNECTED_C && c != -127.0f && c != 85.0f && !isnan(c)) {
                success = true;
                break;
            }
            logMessage(String(labelPrefix) + " idx " + String(i) + " bandymas " + String(attempt + 1) + " klaida: " + String(c));
            delay(250);
        }

        values[i] = c;

        if (success) {
            // Paprasta logika atskiriant ThingSpeak kanalo priskyrimus ar pan. - originaliame kode tai buvo daroma čia.
            // (ThingSpeak siuntimas gal bus ignoruojamas / atskirtas kitoje vietoje).
            ThingSpeak.setField(i + 1, c);
            Blynk.virtualWrite(blynkBaseVpin + i, c);
            logMessage(String(labelPrefix) + " idx " + String(i) + " = " + String(c, 2) + "°C");
            ok_total++;
        } else {
            Blynk.virtualWrite(blynkBaseVpin + i, "N/A");
            logMessage(String(labelPrefix) + " idx " + String(i) + " klaida po " + String(DS_RETRY_COUNT) + " bandymų.");
        }
    }
    digitalWrite(BUS_PWR_CTRL, HIGH);
    delay(50);

    if (ok_total > 0 && tsChannel != 0) {
        int code = ThingSpeak.writeFields(tsChannel, tsApiKey);
        logMessage(String(labelPrefix) + "🌐 ThingSpeak write code=" + String(code));
    }
    return ok_total;
}

void requestDS18B20Temperatures() {
    logMessage("❯❯❯❯ DS18B20 Ciklas: Pradeta konversija (1/3) 💪 MOSFET ĮJUNGIAMAS.");
    digitalWrite(BUS_PWR_CTRL, LOW);
    delay(50);
    sensors1.requestTemperatures();
    sensors2.requestTemperatures();
    sensors3.requestTemperatures();
    sensors4.requestTemperatures();
    logMessage("DS18B20: Konversija paprašyta. Laukiama (~1500ms)...");
}

void readAndPublishDS18B20() {
    logMessage("❯❯❯❯ DS18B20 Ciklas: Skaitomas rezultatus (2/3).");

    if (xSemaphoreTake(networkMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
      auto readBus = [](DallasTemperature& bus, int devCount, float* values, int blynkBaseVpin) -> int {
        int ok_total = 0;
        for (int i = 0; i < devCount && i < 8; i++) {
          float c = DEVICE_DISCONNECTED_C;
          bool success = false;

          for (uint8_t attempt = 0; attempt < DS_RETRY_COUNT; attempt++) {
            c = bus.getTempCByIndex(i);
            if (c != DEVICE_DISCONNECTED_C && c != -127.0f && c != 85.0f && !isnan(c)) {
              success = true;
              break;
            }
            delay(10);
          }

          values[i] = c;
          if (success) {
            Blynk.virtualWrite(blynkBaseVpin + i, c);
            ok_total++;
          } else {
            Blynk.virtualWrite(blynkBaseVpin + i, "N/A");
          }
        }
        return ok_total;
      };

      readBus(sensors1, numberOfDevices1, sensorValues1, 10);
      readBus(sensors2, numberOfDevices2, sensorValues2, 20);
      readBus(sensors3, numberOfDevices3, sensorValues3, 30);
      readBus(sensors4, numberOfDevices4, sensorValues4, 40);

      xSemaphoreGive(networkMutex);
    } else {
      logMessage("KLAIDA: Nepavyko gauti networkMutex per 1s (readAndPublishDS18B20).");
    }

    digitalWrite(BUS_PWR_CTRL, HIGH);
    logMessage("❯❯❯❯ DS18B20: Skaitymas baigtas, 💪 MOSFET IŠJUNGTAS.");
}

void sendDS18B20ToThingSpeak() {
    logMessage("DS18B20 Ciklas: Siunčiama į 🌐 ThingSpeak (3/3).");
    rgbSending();

    if (xSemaphoreTake(networkMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
      auto sendBus = [](unsigned long channel, const char* apiKey, float* values, int count, const char* label) {
          bool hasData = false;
          for (int i = 0; i < count && i < 8; i++) {
              float v = values[i];
              if (v != DEVICE_DISCONNECTED_C && v != -127.0f && v != 85.0f && !isnan(v)) {
                  ThingSpeak.setField(i + 1, String(v, 2).c_str());
                  hasData = true;
              }
          }
          if (hasData) {
              int code = ThingSpeak.writeFields(channel, apiKey);
              logMessage(String(label) + "🌐 ThingSpeak write code=" + String(code));
          } else {
              logMessage(String(label) + "🌐 Nėra validžių duomenų siuntimui į ThingSpeak.");
          }
      };

      sendBus(myChannelNumber1, myWriteAPIKey1, sensorValues1, numberOfDevices1, "130T");
      sendBus(myChannelNumber2, myWriteAPIKey2, sensorValues2, numberOfDevices2, "250T");
      sendBus(myChannelNumber3, myWriteAPIKey3, sensorValues3, numberOfDevices3, "100T");

      // Džiovyklos duomenys (sensors4) dabar OPTIMIZUOTAI siunčiami per sendQuickSensorsToThingSpeak(),
      // nes šis kanalas (293499) naudojamas ir kitiems sistemos jutikliams, taip išvengiant
      // 15 sekundžių ThingSpeak limitų pažeidimo tam pačiam kanalui!

      xSemaphoreGive(networkMutex);
    } else {
      logMessage("KLAIDA: Nepavyko gauti networkMutex per 1s (sendDS18B20ToThingSpeak).");
    }

    rgbOff();
}
void readQuickSensors() {
    sensors_event_t humidity_read, temp_read;
    if (sht45.getEvent(&humidity_read, &temp_read)) {
        currentShtTemp = temp_read.temperature;
        currentShtHum = humidity_read.relative_humidity;
    } else {
        currentShtTemp = NAN;
        currentShtHum = NAN;
    }

    currentVbat = readBatteryVoltage();
    currentBatPercent = isnan(currentVbat) ? 0 : voltageToPercent(currentVbat);
    currentCpuTemp = readCPUTempC();

    if (xSemaphoreTake(networkMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
      Blynk.virtualWrite(V5, currentCpuTemp);
      Blynk.virtualWrite(V6, currentShtTemp);
      Blynk.virtualWrite(V7, currentShtHum);
      Blynk.virtualWrite(V8, WiFi.RSSI());
      Blynk.virtualWrite(V11, currentVbat);
      Blynk.virtualWrite(V12, currentBatPercent);
      xSemaphoreGive(networkMutex);
    } else {
      logMessage("KLAIDA: Nepavyko gauti networkMutex per 1s (readQuickSensors).");
    }
}
void sendQuickSensorsToThingSpeak() {
    rgbSending();

    if (xSemaphoreTake(networkMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
      ThingSpeak.setField(1, String(currentShtTemp, 1).c_str());
      ThingSpeak.setField(2, String(currentShtHum, 1).c_str());
      ThingSpeak.setField(3, String(currentVbat, 2).c_str());
      ThingSpeak.setField(4, String(currentBatPercent).c_str());
      ThingSpeak.setField(5, String(currentCpuTemp, 1).c_str());
      ThingSpeak.setField(6, String(WiFi.RSSI()).c_str());

      // OPTIMIZACIJA: Apjungiame Džiovyklos (Bus4) jutiklių duomenis į tą pačią užklausą
      if (numberOfDevices4 >= 1) {
          float v1 = sensorValues4[0];
          if (v1 != DEVICE_DISCONNECTED_C && v1 != -127.0f && v1 != 85.0f && !isnan(v1)) {
              ThingSpeak.setField(7, String(v1, 2).c_str());
          }
      }
      if (numberOfDevices4 >= 2) {
          float v2 = sensorValues4[1];
          if (v2 != DEVICE_DISCONNECTED_C && v2 != -127.0f && v2 != 85.0f && !isnan(v2)) {
              ThingSpeak.setField(8, String(v2, 2).c_str());
          }
      }

      int code4 = ThingSpeak.writeFields(myChannelNumber4, myWriteAPIKey4);

      xSemaphoreGive(networkMutex);

      rgbSendResult(code4 == 200);
      logMessage(String("🌐 ThingSpeak (SHT/Batt/Sys/Džiovykla) write code=") + String(code4));
    } else {
      logMessage("KLAIDA: Nepavyko gauti networkMutex per 1s (sendQuickSensorsToThingSpeak).");
      rgbSendResult(false);
    }
}

// NAUJA PAGALBINĖ FUNKCIJA: Suformuoja DS18B20 duomenis Terminalui
String formatBusDataForTerminal(float* values, int count, const String& label) {
  String s = label + " Reikšmės: ";
  if (count == 0) return s + "Nera";

  for (int i = 0; i < count; i++) {
    float v = values[i];
    s += String(i + 1) + ":";
    if (v == DEVICE_DISCONNECTED_C || v == -127.0f || v == 85.0f || isnan(v)) {
      s += "err";
    } else {
      s += String(v, 1) + "°C";
    }
    if (i < count - 1) s += ", ";
  }
  return s;
}

// Funkcija, kuri paverčia persikrovimo priežasties kodą į tekstą
String getResetReasonString() {
  esp_reset_reason_t reason = esp_reset_reason();
  switch (reason) {
    case ESP_RST_UNKNOWN:   return "Nežinoma";
    case ESP_RST_POWERON:   return "Įjungimas";
    case ESP_RST_EXT:       return "Išorinis (Reset mygtukas)";
    case ESP_RST_SW:        return "Programinis persikrovimas";
    case ESP_RST_PANIC:     return "Kritinė klaida (Panic)";
    case ESP_RST_INT_WDT:   return "WDT (Interrupt)";
    case ESP_RST_TASK_WDT:  return "WDT (Task)";
    case ESP_RST_WDT:       return "WDT (Kitas)";
    case ESP_RST_DEEPSLEEP: return "Pabudimas iš Deep Sleep";
    case ESP_RST_BROWNOUT:  return "Įtampos kritimas";
    case ESP_RST_SDIO:      return "SDIO";
    default:                return "Nenustatyta (" + String(reason) + ")";
  }
}

// Nauja funkcija, kuri tikrina automatinio režimo sąlygas
void checkAutoMode() {
  bool localAutoHumidityEnabled;

  if (xSemaphoreTake(stateMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
    localAutoHumidityEnabled = autoHumidityEnabled;
    xSemaphoreGive(stateMutex);
  } else {
    return; // Nepavyko gauti mutex, bandysime kitą kartą
  }

  if (!localAutoHumidityEnabled) {
    return; // Nieko nedaryti, jei režimas išjungtas
  }

  // Laiko sinchronizacijos patikrinimas
  if (time(nullptr) < 1000000000) {
    logMessage("🤖 Laukia NTP laiko sinchronizacijos...");
    return;
  }

  bool shouldTurnOff = false;
  String reason = "";

  // 1. Drėgmės patikrinimas
  if (localAutoHumidityEnabled && currentShtHum > 80.0 && !isnan(currentShtHum)) {
    shouldTurnOff = true;
    reason = "drėgmė viršijo 80% (" + String(currentShtHum, 1) + "%)";
  }

  if (shouldTurnOff) {
    if (xSemaphoreTake(stateMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
      bool r1_on = (desiredRelay1State == 1);
      bool r2_on = (desiredRelay2State == 1);

      if (r1_on || r2_on) {
        logMessage("🤖 AUTO: Išjungiamos relės. Priežastis: " + reason);
        if (xSemaphoreTake(networkMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
          if (r1_on) {
            digitalWrite(Relay1, HIGH); // OFF
            desiredRelay1State = 0;
            Blynk.virtualWrite(V3, 0);
          }
          if (r2_on) {
            digitalWrite(Relay2, HIGH); // OFF
            desiredRelay2State = 0;
            Blynk.virtualWrite(V9, 0);
          }
          xSemaphoreGive(networkMutex);
        } else {
          logMessage("KLAIDA: Nepavyko gauti networkMutex (checkAutoMode)");
        }
      }
      xSemaphoreGive(stateMutex);
    }
  }
}

void sendBlynkTerminalData() {
    logMessage("===== 🖥️ PERIODINIS ATNAUJINIMAS =====");
    terminal.println(String("🔌 Sistemos įtampa: ") + String(currentVbat, 2) + "V⚡ (" + String(currentBatPercent) + "%🔋)");
    terminal.println(String("⛅ Oro temp/drėgmė: ") + String(currentShtTemp, 1) + "°C🌡️, " + String(currentShtHum, 1) + "%DH💧");

    // DS18B20 reikšmės
    terminal.println("--- 🌡️ DS18B20 Duomenys ---");
    terminal.println(formatBusDataForTerminal(sensorValues1, numberOfDevices1, "🛢️130T"));
    terminal.println(formatBusDataForTerminal(sensorValues2, numberOfDevices2, "🛢️250T"));
    terminal.println(formatBusDataForTerminal(sensorValues3, numberOfDevices3, "🛢️100T"));
    terminal.println(formatBusDataForTerminal(sensorValues4, numberOfDevices4, "🔥Džiovyklos temperatūra"));

    // Relės statusas
    terminal.println("--- 🎚️ Relių būsena ---");
    terminal.println(String("V:") + getRelayStatus(Relay1) + " K:" + getRelayStatus(Relay2) +
                     " R3:" + getRelayStatus(Relay3) + " R4:" + getRelayStatus(Relay4));

    // Uptime ir persikrovimo priežastis
    logMessage("--- ⚙️ Sistemos būsena ---");
    unsigned long uptimeSeconds = millis() / 1000;
    int days = uptimeSeconds / 86400;
    int hours = (uptimeSeconds % 86400) / 3600;
    int minutes = (uptimeSeconds % 3600) / 60;
    logMessage("Uptime: " + String(days) + "d " + String(hours) + "h " + String(minutes) + "m");
    logMessage("Pask. perkrovimas: " + getResetReasonString());

    terminal.flush();
}

// ===== Sistemos funkcijos (WDT, Reboot, Blynk Handlers) =====
unsigned long wifiDisconnectTime = 0;
bool waitingForWiFi = false;
const unsigned long wifiTimeout = 60000;
unsigned long lastBlynkConnectedTime = 0;
const unsigned long blynkTimeout = 300000; // 5 minutės (300 000 ms)

void checkConnection() {
  // 1. WiFi Prisijungimo Tikrinimas
  if (WiFi.status() != WL_CONNECTED) {
    if (!waitingForWiFi) {
      wifiDisconnectTime = millis();
      waitingForWiFi = true;
    }
    rgbWiFiWait();
    if (waitingForWiFi && (millis() - wifiDisconnectTime >= wifiTimeout)) {
       logMessage("REBOOT: WiFi neatsako > 60s. Perkrovas...");
       delay(100);
       ESP.restart();
    }
  } else {
    waitingForWiFi = false;
  }

  // 2. Blynk Prisijungimo Tikrinimas (net jei WiFi veikia)
  if (Blynk.connected()) {
    lastBlynkConnectedTime = millis();
  } else {
    // Jei Blynk neprisijungęs ilgiau nei nustatytas laikas (pvz. 5 min)
    if (millis() - lastBlynkConnectedTime > blynkTimeout) {
      logMessage("REBOOT: Blynk neatsako > 5min. Perkrovas...");
      delay(100);
      ESP.restart();
    }
  }
}
bool rebootDoneToday = false;
int nowHour() { time_t t = time(NULL); struct tm lt; localtime_r(&t, &lt); return lt.tm_hour; }
int nowMinute() { time_t t = time(NULL); struct tm lt; localtime_r(&t, &lt); return lt.tm_min; }

void checkDailyReboot() {
  // Patikriname, ar laikas sinchronizuotas
  if (time(nullptr) < 1000000000) {
    return; // Laikas dar nenustatytas, nieko nedarome
  }

  int h = nowHour();
  int m = nowMinute();

  // Persikrovimas kasdien 4:00 ryto
  if (h == 4 && m == 0 && !rebootDoneToday) {
    logMessage("Atliekamas kasdienis automatinis persikrovimas...");
    delay(100);
    ESP.restart();
  }

  // Pažymime, kad persikrovimas šiandien atliktas
  if (h == 4 && m > 0) {
    rebootDoneToday = true;
  }

  // Atstatome vėliavėlę kitą valandą (pvz., 5:00)
  if (h == 5) {
    rebootDoneToday = false;
  }
}
String deviceAddressToString(const DeviceAddress deviceAddress) {
  char str[17] = "";
  for (uint8_t i = 0; i < 8; i++) {
    sprintf(&str[i * 2], "%02X", deviceAddress[i]);
  }
  return String(str);
}
void sendStartupDiagnostics() {
  auto printBoth = [](const String& msg) { Serial.println(msg); terminal.println(msg); };

  printBoth("===== 🚀 STARTO DIAGNOSTIKA v" + String(BLYNK_FIRMWARE_VERSION) + " =====");
  printBoth(String("🛜 WiFi RSSI: ") + String(WiFi.RSSI()) + " dBm");

  printBoth("--- ESP32(corex2) Sistema ---");
  printBoth(String("🔌 Sistemos įtampa: ") + String(currentVbat, 2) + "V⚡ (" + String(currentBatPercent) + "%🔋)");
  printBoth(String("🔲 CPU Dažnis: ") + String(getCpuFrequencyMhz()) + " MHz");
  printBoth(String("💿 Laisva RAM: ") + String(esp_get_free_heap_size() / 1024) + " KB");
  printBoth(String("💿 Maks. RAM Blokas: ") + String(heap_caps_get_largest_free_block(MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT) / 1024) + " KB");
  printBoth(String("⚡ Flash Dydis: ") + String(ESP.getChipRevision()));
  printBoth("---------------------");

  auto printBusInfo = [&](DallasTemperature& bus, int count, const char* label) {
    printBoth(String(label) + " (" + String(count) + " jutikliai):");
    for (int i = 0; i < count; i++) {
      DeviceAddress addr;
      if (bus.getAddress(addr, i)) printBoth(String("  idx ") + String(i) + " addr: " + deviceAddressToString(addr));
      else printBoth(String("  idx ") + String(i) + " addr: N/A");
    }
  };
  printBusInfo(sensors1, numberOfDevices1, "Bus1 (🛢️130T)");
  printBusInfo(sensors2, numberOfDevices2, "Bus2 (🛢️250T)");
  printBusInfo(sensors3, numberOfDevices3, "Bus3 (🛢️100T)");
  printBusInfo(sensors4, numberOfDevices4, "Bus4 (🔥Džiovyklos temperatūra)");

  // RELIŲ BŪSENOS VIRTUAL WRITE IŠJUNGIMAS: Relės būsena atkuriama per Blynk.syncVirtual BLYNK_CONNECTED() dalyje.

  printBoth("===== 🚩 DIAGNOSTIKA BAIGTA =====");
  terminal.flush();
}

// ===== BLYNK RELĖS VALDYMAS (SU LED MIRKSĖJIMU) =====
BLYNK_WRITE(V3) {
  if (xSemaphoreTake(stateMutex, portMAX_DELAY) == pdTRUE) {
    if (autoHumidityEnabled) {
      logMessage("🤖 Automatinis režimas blokuoja rankinį V3 valdymą.");
      Blynk.virtualWrite(V3, desiredRelay1State); // Atstatome mygtuko būseną programėlėje
      xSemaphoreGive(stateMutex);
      return;
    }
    int v = param.asInt();
    // V3 (Relay1) - Standartinė logika: Blynk ON (1) -> LOW (ON)
    digitalWrite(Relay1, v ? LOW : HIGH);
    rgbBlink(v);
    logMessage(String("𖣘 Ventiliatorius: ") + (v ? "Įjungtas" : "Išjungtas"));
    desiredRelay1State = v; // Išsaugome būseną
    xSemaphoreGive(stateMutex);
  }
}
BLYNK_WRITE(V9) {
  if (xSemaphoreTake(stateMutex, portMAX_DELAY) == pdTRUE) {
    if (autoHumidityEnabled) {
      logMessage("🤖 Automatinis režimas blokuoja rankinį V9 valdymą.");
      Blynk.virtualWrite(V9, desiredRelay2State); // Atstatome mygtuko būseną programėlėje
      xSemaphoreGive(stateMutex);
      return;
    }
    int v = param.asInt();
    // V9 (Relay2) - Standartinė logika: Blynk ON (1) -> LOW (ON)
    digitalWrite(Relay2, v ? LOW : HIGH);
    rgbBlink(v);
    logMessage(String("𖣘 Kompensacinis: ") + (v ? "Įjungtas" : "Išjungtas"));
    desiredRelay2State = v; // Išsaugome būseną
    xSemaphoreGive(stateMutex);
  }
}

BLYNK_WRITE(V13) {
  int v = param.asInt();
  // V13 (Relay3) - Standartinė logika (Active HIGH): Blynk ON (1) -> HIGH (ON), Blynk OFF (0) -> LOW (OFF)
  digitalWrite(Relay3, v ? HIGH : LOW);
  rgbBlink(v);
  logMessage(String("🎚️ Relė3: ") + (v ? "Įjungta" : "Išjungta"));
  desiredRelay3State = v; // Išsaugome būseną
}
BLYNK_WRITE(V14) {
  int v = param.asInt();
  // V14 (Relay4) - Standartinė logika (Active HIGH): Blynk ON (1) -> HIGH (ON), Blynk OFF (0) -> LOW (OFF)
  digitalWrite(Relay4, v ? HIGH : LOW);
  rgbBlink(v);
  logMessage(String("🎚️ Relė4: ") + (v ? "Įjungta" : "Išjungta"));
  desiredRelay4State = v; // Išsaugome būseną
}

// Nauja funkcija automatiniam režimui valdyti per V15 (Dregme)
BLYNK_WRITE(V15) {
  if (xSemaphoreTake(stateMutex, portMAX_DELAY) == pdTRUE) {
    autoHumidityEnabled = param.asInt(); // 1 = Įjungta, 0 = Išjungta
    logMessage(String("🤖 Auto Drėgmė: ") + (autoHumidityEnabled ? "ĮJUNGTA" : "IŠJUNGTA"));
    xSemaphoreGive(stateMutex);
  }
}

BLYNK_WRITE(V1) {
  if (param.asInt() == 1) {
    logMessage("🔄 Paleistas valdiklio perkrovimas... Palaukite");
    delay(200);
    ESP.restart();
  }
}

BLYNK_WRITE(V2) {
  String cmd = param.asString();
  cmd.trim();
  cmd.toLowerCase();

  if (cmd == "ds18b20") {
    terminal.println("--- DS18B20 ADRESAI IR TEMPERATŪROS ---");

    auto printBusDetails = [&](DallasTemperature& bus, float* values, int count, const char* label) {
      terminal.println(String(label) + ":");
      for (int i = 0; i < count; i++) {
        DeviceAddress addr;
        String addrStr = "N/A";
        if (bus.getAddress(addr, i)) {
          addrStr = deviceAddressToString(addr);
        }
        float temp = values[i];
        String tempStr = "err";
        if (temp != DEVICE_DISCONNECTED_C && temp != -127.0f && temp != 85.0f && !isnan(temp)) {
          tempStr = String(temp, 1) + "C";
        }
        terminal.println(String("  idx ") + String(i) + " addr: " + addrStr + " - " + tempStr);
      }
    };

    printBusDetails(sensors1, sensorValues1, numberOfDevices1, "Bus1 (130T)");
    printBusDetails(sensors2, sensorValues2, numberOfDevices2, "Bus2 (250T)");
    printBusDetails(sensors3, sensorValues3, numberOfDevices3, "Bus3 (100T)");
    printBusDetails(sensors4, sensorValues4, numberOfDevices4, "Bus4 (Džiovyklos temperatūra)");
    terminal.flush();
  } else {
    terminal.println("Nežinoma komanda. Bandykite: ds18b20");
    terminal.flush();
  }
}

// *************************************************************
// ********** SETUP FUNKCIJA ***********************************
// *************************************************************
void setup() {
  Serial.begin(115200);
  delay(200);

  // Sukuriame semaforus PRIEŠ pradedant juos naudoti
  serialMutex = xSemaphoreCreateMutex();
  networkMutex = xSemaphoreCreateMutex();
  stateMutex = xSemaphoreCreateMutex(); // Inicializuojame naują mutex

  // Pins / Initial states
  pinMode(PIN_R, OUTPUT); pinMode(PIN_G, OUTPUT); pinMode(PIN_B, OUTPUT);
  pinMode(Relay1, OUTPUT); digitalWrite(Relay1, HIGH); // Pradinė OFF
  pinMode(Relay2, OUTPUT); digitalWrite(Relay2, HIGH); // Pradinė OFF
  pinMode(Relay3, OUTPUT); digitalWrite(Relay3, LOW);  // Pradinė ON (Atvirkštinė logika)
  pinMode(Relay4, OUTPUT); digitalWrite(Relay4, LOW);  // Pradinė ON (Atvirkštinė logika)
  pinMode(BUS_PWR_CTRL, OUTPUT); digitalWrite(BUS_PWR_CTRL, HIGH);
  pinMode(BAT_ADC_PIN, INPUT);

  // I2C, DS18B20, SHT45
  Wire.begin(21, 22);
  sensors1.begin(); sensors2.begin(); sensors3.begin(); sensors4.begin();

  // Nustatome DS18B20 rezoliuciją į 11 bitų (0.125°C žingsnis)
  sensors1.setResolution(11);
  sensors2.setResolution(11);
  sensors3.setResolution(11);
  sensors4.setResolution(11);
  logMessage("🌡️ DS18B20 rezoliucija nustatyta į 11 bitų (0.125°C).");

  numberOfDevices1 = sensors1.getDeviceCount();
  numberOfDevices2 = sensors2.getDeviceCount();
  numberOfDevices3 = sensors3.getDeviceCount();
  numberOfDevices4 = sensors4.getDeviceCount();
  shtOK = sht45.begin();
  if (shtOK) { sht45.setPrecision(SHT4X_HIGH_PRECISION); sht45.setHeater(SHT4X_NO_HEATER); }

  // LCD start screen
  u8g2.begin();
  u8g2.enableUTF8Print();
  u8g2.setContrast(200);
  u8g2.setFont(u8g2_font_6x12_t_cyrillic);
  u8g2.setFontMode(1);

  // 1. Bitmap atvaizdas
  u8g2.firstPage();
  do {
    u8g2.setDrawColor(1);
    u8g2.drawXBM(0, 0, 128, 64, epd_bitmap_download);
  } while ( u8g2.nextPage() );
  rgbStartupSequence();

  // 2. LOADING BAR 3s (su versijos pozicijos pataisymu)
  uint32_t startLoad = millis();
  uint16_t barWidth = 0;

  while (millis() - startLoad < 3000) {
    float progress = float(millis() - startLoad) / 3000.0;
    barWidth = progress * 128;

    u8g2.firstPage();
    do {
      u8g2.setFont(u8g2_font_6x12_t_cyrillic);
      const char* title = "-GRUDU TEMPERATUROS-";
      int titleWidth = u8g2.getStrWidth(title);
      u8g2.drawStr((128 - titleWidth) / 2, 10, title);
      u8g2.drawStr(0, 20, "Valdiklis ESP32 Thing");

      // Programos versijos numerio pozicija
      const char* verLabel = "Programos ver.: ";
      u8g2.drawStr(0, 30, verLabel);
      int verX = u8g2.getStrWidth(verLabel);
      u8g2.drawStr(verX, 30, BLYNK_FIRMWARE_VERSION);

      u8g2.drawStr(0, 40, "Sist. itampa 3.3-4.2V");
      u8g2.drawStr(0, 50, "Kraunasi palaukite...");
      u8g2.drawBox(0, 56, barWidth, 8);
    } while (u8g2.nextPage());

    delay(30);
  }

  // 3. Sensorių kiekio ekranas
  u8g2.firstPage();
  do {
    u8g2.setFont(u8g2_font_6x12_t_cyrillic);

    int mosfetState = digitalRead(BUS_PWR_CTRL);
    String mosfetLine = String("MOSFET DS18B20: ") + (mosfetState == HIGH ? "ON" : "OFF");
    u8g2.drawStr(0, 10, mosfetLine.c_str());

    u8g2.drawStr(0, 20, ("v Rasta davikliu v"));
    u8g2.drawStr(0, 30, ("Bokste 130T: " + String(numberOfDevices1)).c_str());
    u8g2.drawStr(0, 40, ("Bokste 250T: " + String(numberOfDevices2)).c_str());
    u8g2.drawStr(0, 50, ("Bokste 100T: " + String(numberOfDevices3)).c_str());

    String shtLine = "SHT45: ";
    shtLine += (shtOK ? "OK" : "Nerastas!");
    u8g2.drawStr(0, 60, shtLine.c_str());

  } while (u8g2.nextPage());
  rgbStartupSequence();
  delay(1000);

  // PRADĖTI TINKLO INICIALIZAVIMĄ
  WiFi.mode(WIFI_STA);
  BlynkEdgent.begin();
  ThingSpeak.begin(client);
  logMessage("🌐 Tinklo inicilizacija pradėta. Pereinama į loop().");

  readQuickSensors();
  sendQuickSensorsToThingSpeak();

  // ************************************************
  // PRADINIS DS18B20 CIKLAS
  // ************************************************
  if (numberOfDevices1 > 0 || numberOfDevices2 > 0 || numberOfDevices3 > 0 || numberOfDevices4 > 0) {
      logMessage("🌡️ DS18B20: Paleidžiamas pradinis patikimas nuskaitymas (blokuojantis)...");

      readBusAndPublishBlocking(sensors1, numberOfDevices1, sensorValues1, 10, "130T", myChannelNumber1, myWriteAPIKey1);
      readBusAndPublishBlocking(sensors2, numberOfDevices2, sensorValues2, 20, "250T", myChannelNumber2, myWriteAPIKey2);
      readBusAndPublishBlocking(sensors3, numberOfDevices3, sensorValues3, 30, "100T", myChannelNumber3, myWriteAPIKey3);
      readBusAndPublishBlocking(sensors4, numberOfDevices4, sensorValues4, 40, "Džiovyklos temperatūra", 0, ""); // ThingSpeak API keys handled elsewhere if needed

      logMessage("🌡️ DS18B20: Pradinis nuskaitymas baigtas. Duomenys paruošti.");
  } else {
      logMessage("🌡️ DS18B20: Jutiklių nerasta. Pradinis ciklas praleistas.");
  }
  // ************************************************


  // ********** BLYNKTimer NUSTATYMAI **********
  timer.setInterval(5000L, drawLCD);
  timer.setInterval(30000L, readQuickSensors);
  timer.setInterval(180000L, sendBlynkTerminalData);
  timer.setInterval(120000L, sendQuickSensorsToThingSpeak);

  const unsigned long LATAUS_CIKLAS_MS = 120000L;

  // PERIODINIAM DS18B20 NUSKAITYMUI NAUDOJAMA NEBLOKUOJANTI LOGIKA
  timer.setInterval(LATAUS_CIKLAS_MS, []() {
      requestDS18B20Temperatures();
      timer.setTimer(DS_CONV_DELAY_MS, readAndPublishDS18B20, 1);
      timer.setTimer(DS_CONV_DELAY_MS + 500L, sendDS18B20ToThingSpeak, 1);
  });

  timer.setInterval(30000L, checkDailyReboot);
  timer.setInterval(60000L, checkAutoMode); // Tikriname automatinio režimo sąlygas kas minutę
  timer.setInterval(200L, rgbFadeLoop);

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  setenv("TZ", "EET-2EEST,M3.5.0/3,M10.5.0/4", 1);

  // Inicijuojame WDT (30s)
  esp_task_wdt_deinit();
  esp_task_wdt_config_t config;
  config.timeout_ms = 30000; // 30 sekundžių timeout sistemos užstrigimui
  config.trigger_panic = true;
  esp_task_wdt_init(&config);
  esp_task_wdt_add(NULL); // Pridedame esamą užduotį (loop / Core 0)

  // Sukuriame ir paleidžiame laikmačio užduotį 1-ajame branduolyje
  xTaskCreatePinnedToCore(
      timerTask,            // Funkcija, kurią vykdys užduotis
      "TimerTask",          // Užduoties pavadinimas
      8192,                 // Steko dydis
      NULL,                 // Parametrai
      1,                    // Prioritetas
      &TimerTaskHandle,     // Užduoties valdiklis
      1);                   // Branduolys (Core 1)
}

// *************************************************************
// ********** LOOP FUNKCIJA (VEIKIA CORE 0) ********************
// *************************************************************
void loop() {
  esp_task_wdt_reset(); // Neresetinam WDT, kad nepersikrautų
  BlynkEdgent.run();
  checkConnection(); // checkConnection perkeltas čia, kad veiktų Core 0
  vTaskDelay(pdMS_TO_TICKS(10));
}

BLYNK_CONNECTED() {
  sendStartupDiagnostics();

  // RELIŲ BŪSENOS ATKŪRIMAS: Prašome Blynk serverio atsiųsti
  Blynk.syncVirtual(V3, V9, V13, V14);
}


// *************************************************************
// ********** LAIKMAČIO UŽDUOTIS (VEIKIA CORE 1) ***************
// *************************************************************
void timerTask(void *pvParameters) {
  logMessage("INFO: TimerTask paleista Core 1.");
  esp_task_wdt_add(NULL); // Pridedame šią užduotį prie WDT stebėjimo
  for (;;) {
    esp_task_wdt_reset(); // Neresetinam WDT
    timer.run();
    vTaskDelay(pdMS_TO_TICKS(10)); // Suteikiame laiko kitoms užduotims
  }
}