# ESP32-S3 AI Object Detection with Gemini 2.0

Šis projektas naudoja **DFRobot ESP32-S3 AI Camera (v1.1)** modulį kartu su **Gemini 2.0 Flash API**, kad atpažintų objektus (žmones, automobilius) ir siųstų informaciją į **Firestore RTDB**.

## Funkcijos
- **Objektų atpažinimas:** Atpažįsta žmones (SIGNAL:1) ir automobilius (SIGNAL:2) naudojant Gemini AI.
- **Valdymo pultas:** Valdymo sąsaja per naršyklę (Port 80) ir MJPEG vaizdo srautas (Port 81).
- **Periferija:** Naudoja LTR-308 šviesos sensorių, MAX98357A garsiakalbį (I2S) ir Flash LED.
- **Lietuviškas palaikymas:** AI aprašymai ir atsakymai pateikiami lietuvių kalba.

## Failų Struktūra
- `GeminiAI_ObjectDetection.ino`: Pagrindinis programos kodas (WiFi, AI logika, Serveris, I2S).
- `camera_index.h`: Naršyklės sąsajos HTML kodas (suglaudintas GZIP formatu).

## Naudojimas
1. Įkelkite abu failus į Arduino IDE.
2. Pasirinkite plokštę: `DFRobot FireBeetle 2 ESP32-S3`.
3. Nustatymai: USB CDC "Enabled", PSRAM "OPI PSRAM", Flash "16MB".
4. Serijiniame monituje įrašykite `start`, kad pradėtumėte AI analizę.
