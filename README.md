# LoRa DX-LR22 (868MHz) ir ESP32-C3 Valdymo Sistema (Dashboard)

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
- `lora_dashboard.ahk` – AutoHotkey 2.0 valdymo skydelis (Dashboard) kompiuteriui.
- `README.md` – Projekto dokumentacija ir instrukcijos.

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
| `RGB:r,g,b` | Kompiuteris | Nustato RGB LED spalvą (pvz., `RGB:255,0,0`). Atsakymas: `RGB_OK:r,g,b` |
| `PING` | Kompiuteris | Patikrina ryšį. Atsakymas: `PONG` |
| `GET_TEMP` | Kompiuteris | Užklausia CPU temperatūros. Atsakymas: `CPU_TEMP:xx.x` |
| `OFF` | Kompiuteris | Išjungia RGB LED. Atsakymas: `RGB_OK:0,0,0` |
| `CPU_TEMP:xx.x` | ESP32-C3 | Automatinis periodinis (kas 5s) temperatūros siuntimas. |
