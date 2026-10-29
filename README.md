# LoRa DX-LR22 (868MHz) ir ESP32-C3 Valdymo Sistema (Dashboard v2.0)

Ši sistema skirta dvikypčiam ryšiui tarp **AutoHotkey v2** valdymo pulto (Dashboard) kompiuteryje ir **ESP32-C3** mikrokontrolerio su **DX-LR22 868MHz LoRa** moduliu bei **RGB Neopixel** šviesos diodu.

---

## 🛠 Sistemos Schema ir Sujungimai

### ESP32-C3 <-> DX-LR22 868MHz LoRa Modulis
| ESP32-C3 Pin | DX-LR22 Pin | Aprašymas |
| :--- | :--- | :--- |
| **GPIO 7 (TX1)** | **RXD** | LoRa duomenų gavimas (Serial1 TX) |
| **GPIO 6 (RX1)** | **TXD** | LoRa duomenų siuntimas (Serial1 RX) |
| **3.3V / 5V** | **VCC** | Maitinimas |
| **GND** | **GND** | Bendra žemė |

### ESP32-C3 <-> RGB Neopixel LED
| ESP32-C3 Pin | RGB LED Pin | Aprašymas |
| :--- | :--- | :--- |
| **GPIO 8** | **DIN / Data** | Neopixel valdymo signalas |
| **3.3V / 5V** | **VCC** | Maitinimas |
| **GND** | **GND** | Bendra žemė |

---

## 📁 Projekto Failai

- `esp32_c3_lora.ino` – ESP32-C3 mikrokontrolerio programa (Arduino IDE / PlatformIO).
- `lora_dashboard.ahk` – AutoHotkey 2.0 valdymo skydelis (Dashboard v2.0) kompiuteriui.
- `README.md` – Projekto dokumentacija ir instrukcijos.

---

## ✨ Naujos V2.0 Ypatybės ir Patobulinimai

1. **Žurnalas slenka žemyn (Downwards scrolling log console):** Naujausi įvykiai ir žinutės pridedami apačioje su automatiniu prasukimu (auto-scroll).
2. **Ping ryšio vėlavimo matavimas (Latency):** Siunčiama `PING:<seq>` ir matuojamas tikslus atsakymo laikas milisekundėmis (ms).
3. **Platesnė telemetrija:** Rodoma CPU temperatūra (°C), veikimo laikas (*Uptime* valandomis/minutėmis/sekundėmis) bei laisva RAM atmintis (KB).
4. **Šviesos efektai:** Palaikomi animuoti šviesos diodo efektai (`EFFECT:RAINBOW`, `EFFECT:BLINK`, `EFFECT:STROBE`).
5. **ESP32 Nuotolinis Perkrovimas:** Galimybė saugiai perkrauti mikrokontrolerį komanda `RESET`.

---

## 🚀 Kaip Paleisti Programą

### 1. ESP32-C3 Įrašymas
1. Atsidarykite `esp32_c3_lora.ino` su Arduino IDE.
2. Įdiekite `Adafruit NeoPixel` biblioteką (per *Tools -> Manage Libraries*).
3. Pasirinkite plokštę **ESP32C3 Dev Module**.
4. Įrašykite kodą į ESP32-C3.

### 2. AutoHotkey 2.0 Dashboard Paleidimas
1. Įsitikinkite, kad kompiuteryje įdiegtas [AutoHotkey v2.0+](https://www.autohotkey.com/).
2. Prijunkite LoRa imtuvą (pvz., USB-UART konverterį su DX-LR22 moduliu) prie kompiuterio USB prievado.
3. Dukart spustelėkite `lora_dashboard.ahk`.
4. Pasirinkite atitinkamą COM prievadą ir spauskite **Prisijungti**.

---

## 💬 Komandų Protokolas (ASCII / Serial 9600 Baud)

| Komanda | Siuntėjas | Aprašymas / Atsakymas |
| :--- | :--- | :--- |
| `RGB:r,g,b` | Kompiuteris | Nustato statinę RGB LED spalvą (pvz., `RGB:255,0,0`). Atsakymas: `RGB_OK:r,g,b` |
| `EFFECT:<pavadinimas>` | Kompiuteris | Paleidžia efektą: `RAINBOW`, `BLINK`, `STROBE`, `OFF`. Atsakymas: `EFFECT_OK:<pavadinimas>` |
| `PING` / `PING:<id>` | Kompiuteris | Patikrina ryšį ir matuoja vėlavimą. Atsakymas: `PONG` / `PONG:<id>` |
| `SYS_INFO` | Kompiuteris | Užklausia sistemos info. Atsakymas: `SYS_INFO:TEMP=xx.x,UPTIME=sec,HEAP=bytes` |
| `GET_TEMP` | Kompiuteris | Užklausia CPU temperatūros. Atsakymas: `CPU_TEMP:xx.x` |
| `RESET` | Kompiuteris | Perkrauna ESP32-C3. Atsakymas: `SYS_RESETTING` |
| `OFF` | Kompiuteris | Išjungia RGB LED. Atsakymas: `RGB_OK:0,0,0` |
| `CPU_TEMP:xx.x` | ESP32-C3 | Automatinis periodinis (kas 5s) temperatūros siuntimas. |
