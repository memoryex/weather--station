# ESP32-S3 AI Object Detection & Web Management

Šis projektas transformuoja **DFRobot ESP32-S3 AI Camera** modulį į išmanią objektų atpažinimo sistemą su integruotu įgarsinimu ir nuotoliniu valdymu.

## 🚀 Funkcijos
- **AI Objektų Atpažinimas**: Naudoja *Gemini 1.5 Flash API* analizuoti vaizdus kas 60 sekundžių. Sistema atpažįsta žmones, automobilius ir kitus objektus.
- **Lietuviškas Įgarsinimas (TTS)**: Atpažinti objektai įgarsinami aiškia lietuvių kalba per integruotą garsiakalbį.
- **Web Valdymo Pultas**: Per įrenginio IP adresą pasiekiamas puslapis, leidžiantis tiesiogiai stebėti vaizdą ir derinti kameros parametrus (ryškumą, kontrastą, pasukimą ir kt.).
- **Debesų Sinchronizacija**: Visi aptikimai (aprašymas, laikas, nuotrauka Base64 formatu) automatiškai siunčiami į *Firestore Realtime Database*.
- **Išmanus WiFi Valdymas**: Įsimena tinklo nustatymus, o nepavykus prisijungti – leidžia įvesti naujus duomenis per Serial Monitor.

## 🛠 Įranga
- **Modulis**: DFRobot DFR1154 ESP32-S3 AI CAM (v1.1).
- **Sensorius**: OV3660 (3MP kamera).
- **Audio**: MAX98357 I2S stiprintuvas su garsiakalbiu.
- **Papildomai**: Integruotas LED blykstė ir šviesos sensorius.

## 💻 Galimybės ir Valdymas
Per Serial Monitor galima valdyti sistemą šiomis komandomis:
- `start`: Pradėti automatinį AI stebėjimą.
- `stop`: Sustabdyti AI stebėjimą (lieka tik web serveris).
- `test`: Atlikti pilną įrangos savidiagnostiką (LED, garsiakalbis, kamera).
- `list`: Patikrinti Gemini API prieinamus modelius.

Projektas sukurtas efektyviam stebėjimui, užtikrinant stabilų vaizdo srautą (MJPEG) ir greitą AI reakciją.
