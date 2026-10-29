# LoRa DX-LR22 (868MHz) ir ESP32-C3 Valdymo Sistema (Dashboard v3.0)

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
- `lora_dashboard.ahk` – AutoHotkey 2.0 valdymo skydelis (Dashboard v3.0) kompiuteriui.
- `README.md` – Projekto dokumentacija ir instrukcijos.

---

## ✨ V3.0 Naujovės ir Ypatybės

1. **Signalo Stiprumas (RSSI dBm ir Procentai):**
   - Rodo tikslų signalo lygį decibelais millivatais (dBm) (pvz. `-70 dBm`).
   - Apskaičiuoja signalo kokybės procentus $0\% - 100\%$ (skalėje nuo $-134\text{ dBm}$ iki $-70\text{ dBm}$, kur $-70\text{ dBm}$ ir daugiau rodo $100\%$ kokybę).
   - Dinaminė spalvota signalo progreso juosta (Žalia > 65%, Oranžinė `cFF8C00` > 35%, Raudona <= 35%).

2. **Atstumo Įvertinimas & Įrankio Kalibravimas:**
   - Skaičiuoja atstumą metrais ir kilometrais pagal fizikinį modelį:
     $$d = 10^{\frac{\text{TxPower}_{1m} - \text{RSSI}}{10 \cdot n}}$$
   - **Tiesioginis Kalibravimas:** Įveskite žinomą faktinį atstumą (pvz., `2.0` m) ir spustelėkite **🎯 Kalibruoti**. Programa automatiškai perskaičiuos atskaitos galią 1 metrui:
     $$\text{TxPower}_{1m} = \text{RSSI} + (10 \cdot n \cdot \log_{10}(d_{\text{žinomas}}))$$

3. **Automatinis Periodinis Telemetrijos & Ping Atnaujinimas:**
   - ESP32-C3 automatiškai kas 5s siunčia pilną **`SYS_INFO`** telemetriją (CPU Temp, Uptime, Laisva RAM, RSSI).
   - AHK Dashboard turi automatinį foninį PING laikmatį, kuris reguliariai matuoja **Ryšio Vėlavimą** (ms).

4. **Žurnalas slenka žemyn (Downwards scrolling log console):**
   - Naudoja Multi +VScroll ir Win32 prasukimo pranešimus; kiekviena nauja eilutė eina žemyn po ankstesnės su tikrais `` `r`n `` simboliais.

5. **Šviesos efektai & Komandos:**
   - Animuoti šviesos diodo efektai (`EFFECT:RAINBOW`, `EFFECT:BLINK`, `EFFECT:STROBE`).
   - Saugus ESP32 perkrovimas komanda `RESET`.

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
| `PING` / `PING:<id>` | Kompiuteris | Patikrina ryšį ir matuoja vėlavimą. Atsakymas: `PONG,RSSI=x` / `PONG:<id>,RSSI=x` |
| `SYS_INFO` | Kompiuteris / ESP32 | Užklausia / automatiškai kas 5s siunčia sistemos info. Atsakymas: `SYS_INFO:TEMP=x,UPTIME=sec,HEAP=bytes,RSSI=x` |
| `GET_TEMP` | Kompiuteris | Užklausia CPU temperatūros. Atsakymas: `CPU_TEMP:x,RSSI=x` |
| `SET_RSSI:<dbm>` | Kompiuteris | Nustato / testuoja Bazinį RSSI lygį dBm. Atsakymas: `RSSI_OK:<dbm>` |
| `RESET` | Kompiuteris | Perkrauna ESP32-C3. Atsakymas: `SYS_RESETTING` |
| `OFF` | Kompiuteris | Išjungia RGB LED. Atsakymas: `RGB_OK:0,0,0` |
